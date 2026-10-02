const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Filter,
} = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { DateTime } = require("luxon");

initializeApp();

// Named (non-default) Firestore database used by the Flutter app.
const db = getFirestore("clearcase");

// Reminder doc → days to subtract from event date. Labels match
// remindMeOptions in lib/models/remainder_model.dart.
const REMIND_OFFSET_DAYS = {
  "On day of event": 0,
  "1 day before": 1,
  "A week before": 7,
};
const REMINDER_OFF = "No notification";

// scheduledRules doc → days to shift the entire [start, end] window earlier.
const SCHEDULED_RULE_OFFSET_DAYS = {
  "On the Scheduled day": 0,
  "1 Day Before": 1,
  "7 Days Before": 7,
};
const SCHEDULED_RULE_OFF = "Turn Off Notifications";

function capitalize(s) {
  if (!s) return "";
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function formatScheduledDate(isoStr) {
  if (!isoStr) return "";
  const dt = DateTime.fromISO(isoStr);
  if (!dt.isValid) return isoStr;
  return dt.toFormat("LLL d, yyyy");
}

function formatScheduledTime(timeStr) {
  if (!timeStr) return "";
  const parts = String(timeStr).split(":");
  if (parts.length < 2) return timeStr;
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  if (isNaN(h) || isNaN(m)) return timeStr;
  return DateTime.fromObject({ hour: h, minute: m }).toFormat("h:mm a");
}

// Whether a reminder falls on `day` (a luxon DateTime at start of day in the
// user's zone). Mirrors ReminderModel.occursOn in the app: a single reminder
// is on its date; a repeated one is on its chosen weekdays (Mon=1..Sun=7) in
// every `intervalWeeks`-th week, counting from the week of its start date,
// between that date and its optional ruleEndDate.
function reminderOccursOn(reminder, day, timezone) {
  const start = DateTime.fromJSDate(reminder.date.toDate())
    .setZone(timezone)
    .startOf("day");
  const weekdays = Array.isArray(reminder.weekdays) ? reminder.weekdays : [];
  if (reminder.isRepeat !== true || weekdays.length === 0) {
    return day.hasSame(start, "day");
  }
  if (day < start) return false;
  if (reminder.ruleEndDate) {
    const end = DateTime.fromJSDate(reminder.ruleEndDate.toDate())
      .setZone(timezone)
      .startOf("day");
    if (day > end) return false;
  }
  if (!weekdays.includes(day.weekday)) return false;
  const interval = [1, 2, 3, 4].includes(reminder.intervalWeeks)
    ? reminder.intervalWeeks
    : 1;
  const startMonday = start.minus({ days: start.weekday - 1 });
  const dayMonday = day.minus({ days: day.weekday - 1 });
  // Round: a DST change makes the span a few hours off whole days.
  const weeks = Math.round(dayMonday.diff(startMonday, "days").days / 7);
  return weeks % interval === 0;
}

// The zone to evaluate a user's day in. `timezone` should be an IANA name
// ("Australia/Sydney"), but app builds before Oct 2026 saved the literal
// "TimezoneInfo". Fall back to the fixed `utcOffset` the app also saves
// ("+10:00"); it ignores later DST changes but is right to within an hour.
function resolveZone(user) {
  const tz = user.timezone;
  if (tz && DateTime.now().setZone(tz).isValid) return tz;
  const m = /^([+-])(\d{1,2}):?(\d{2})$/.exec(String(user.utcOffset || "").trim());
  if (m) {
    const zone = `UTC${m[1]}${parseInt(m[2], 10)}${m[3] === "00" ? "" : ":" + m[3]}`;
    if (DateTime.now().setZone(zone).isValid) return zone;
  }
  return null;
}

function joinChildNames(appliedChildren) {
  if (!Array.isArray(appliedChildren)) return "";
  return appliedChildren
    .map((c) => (c && c.name ? String(c.name).trim() : ""))
    .filter((n) => n.length > 0)
    .join(", ");
}

async function handleInvalidToken(userDocRef, userId, err) {
  if (
    err.code === "messaging/registration-token-not-registered" ||
    err.code === "messaging/invalid-registration-token" ||
    err.code === "messaging/invalid-argument"
  ) {
    await userDocRef.update({
      fcmToken: FieldValue.delete(),
      tokenUpdatedAt: FieldValue.serverTimestamp(),
    });
    logger.info("Removed invalid FCM token", { userId });
  }
}

exports.pushNotifications = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "UTC",
    region: "us-central1",
    memory: "256MiB",
  },
  async () => {
    const nowUtc = DateTime.utc();
    logger.info("Run started", { utc: nowUtc.toISO() });

    // Only fetch users who have at least one of the two notification
    // categories enabled. Per-user, we still check the specific flag below.
    const usersSnap = await db
      .collection("users")
      .where(
        Filter.or(
          Filter.where("isRemindersEnabled", "==", true),
          Filter.where("isScheduledDatesEnabled", "==", true)
        )
      )
      .get();

    let sentCount = 0;
    let scannedReminders = 0;
    let scannedRules = 0;

    for (const userDoc of usersSnap.docs) {
      const user = userDoc.data();
      const userId = userDoc.id;
      const fcmToken = user.fcmToken;
      const notificationTime = user.notificationTime;
      if (!fcmToken || !notificationTime) continue;

      const timezone = resolveZone(user);
      if (!timezone) {
        logger.warn("No usable timezone for user", {
          userId,
          timezone: user.timezone,
          utcOffset: user.utcOffset,
        });
        continue;
      }
      const nowLocal = nowUtc.setZone(timezone);

      // Window-based trigger: fire once we're at or past the user's
      // notificationTime today, and rely on each doc's lastNotifiedDate guard
      // below to prevent duplicates. This tolerates Scheduler drift, cold
      // starts, DST gaps, and mid-day toggle-ons that an exact-minute equality
      // check would silently miss.
      const [hStr, mStr] = String(notificationTime).split(":");
      const triggerHour = parseInt(hStr, 10);
      const triggerMinute = parseInt(mStr, 10);
      if (isNaN(triggerHour) || isNaN(triggerMinute)) {
        logger.warn("Invalid notificationTime format", {
          userId,
          notificationTime,
        });
        continue;
      }

      const triggerLocal = nowLocal.set({
        hour: triggerHour,
        minute: triggerMinute,
        second: 0,
        millisecond: 0,
      });
      if (!triggerLocal.isValid) continue;
      if (nowLocal < triggerLocal) continue;

      const todayStart = nowLocal.startOf("day");
      const todayStr = todayStart.toISODate();

      const remindersOn = user.isRemindersEnabled === true;
      const rulesOn = user.isScheduledDatesEnabled === true;

      const casesSnap = await userDoc.ref.collection("cases").get();

      for (const caseDoc of casesSnap.docs) {
        // ─── REMINDERS (gated by isRemindersEnabled) ───────────────────────
        if (remindersOn) {
          const remindersSnap = await caseDoc.ref
            .collection("reminders")
            .get();

          for (const reminderDoc of remindersSnap.docs) {
            scannedReminders++;
            const reminder = reminderDoc.data();
            if (!reminder.date) continue;
            if (reminder.remindMeOption === REMINDER_OFF) continue;

            const offsetDays = REMIND_OFFSET_DAYS[reminder.remindMeOption];
            if (offsetDays === undefined) continue;

            // Notify today when the reminder falls `offsetDays` from now.
            const eventDay = todayStart.plus({ days: offsetDays });
            if (!reminderOccursOn(reminder, eventDay, timezone)) continue;
            if (reminder.lastNotifiedDate === todayStr) continue;

            try {
              await getMessaging().send({
                token: fcmToken,
                notification: {
                  title: reminder.title || "Reminder",
                  body: reminder.type || "",
                },
                data: {
                  kind: "reminder",
                  type: reminder.type || "",
                  title: reminder.title || "",
                  description: reminder.description || "",
                  caseId: reminder.caseId || caseDoc.id,
                  reminderId: reminderDoc.id,
                },
                android: {
                  priority: "high",
                  notification: {
                    channelId: "high_importance_channel",
                    sound: "default",
                  },
                },
                apns: {
                  headers: { "apns-priority": "10" },
                  payload: {
                    aps: { sound: "default", contentAvailable: true },
                  },
                },
              });

              await reminderDoc.ref.update({
                lastNotifiedDate: todayStr,
                lastNotifiedAt: FieldValue.serverTimestamp(),
              });

              sentCount++;
              logger.info("Reminder notification sent", {
                userId,
                reminderId: reminderDoc.id,
                title: reminder.title,
              });
            } catch (err) {
              logger.error("FCM send failed (reminder)", {
                userId,
                reminderId: reminderDoc.id,
                code: err.code,
                message: err.message,
              });
              await handleInvalidToken(userDoc.ref, userId, err);
            }
          }
        }

        // ─── SCHEDULED RULES (gated by isScheduledDatesEnabled) ───────────
        if (rulesOn) {
          const rulesSnap = await caseDoc.ref
            .collection("scheduledRules")
            .get();

          for (const ruleDoc of rulesSnap.docs) {
            scannedRules++;
            const rule = ruleDoc.data();

            if (!rule.startDate) continue;
            if (rule.notificationPref === SCHEDULED_RULE_OFF) continue;

            const offsetDays =
              SCHEDULED_RULE_OFFSET_DAYS[rule.notificationPref];
            if (offsetDays === undefined) continue;

            // The "scheduled day" is today shifted forward by the offset.
            // We fire when that day lies within [startDate, endDate].
            const scheduledDay = todayStart.plus({ days: offsetDays });

            const startDate = DateTime.fromISO(rule.startDate, {
              zone: timezone,
            }).startOf("day");
            if (!startDate.isValid) continue;
            if (scheduledDay < startDate) continue;

            if (rule.hasEndDate === true && rule.endDate) {
              const endDate = DateTime.fromISO(rule.endDate, {
                zone: timezone,
              }).startOf("day");
              if (endDate.isValid && scheduledDay > endDate) continue;
            }

            if (rule.lastNotifiedDate === todayStr) continue;

            const childNames = joinChildNames(rule.appliedChildren);
            const title = childNames || "Scheduled";
            const dateText = formatScheduledDate(rule.startDate);
            const timeText = formatScheduledTime(rule.startTime);
            const bodyParts = [capitalize(rule.category)];
            if (dateText) bodyParts.push(dateText);
            const body =
              bodyParts.join(" · ") + (timeText ? ` at ${timeText}` : "");

            try {
              await getMessaging().send({
                token: fcmToken,
                notification: { title, body },
                data: {
                  kind: "scheduledRule",
                  category: rule.category || "",
                  caseId: caseDoc.id,
                  ruleId: ruleDoc.id,
                  startDate: rule.startDate || "",
                  startTime: rule.startTime || "",
                },
                android: {
                  priority: "high",
                  notification: {
                    channelId: "high_importance_channel",
                    sound: "default",
                  },
                },
                apns: {
                  headers: { "apns-priority": "10" },
                  payload: {
                    aps: { sound: "default", contentAvailable: true },
                  },
                },
              });

              await ruleDoc.ref.update({
                lastNotifiedDate: todayStr,
                lastNotifiedAt: FieldValue.serverTimestamp(),
              });

              sentCount++;
              logger.info("Scheduled rule notification sent", {
                userId,
                caseId: caseDoc.id,
                ruleId: ruleDoc.id,
                category: rule.category,
                pref: rule.notificationPref,
              });
            } catch (err) {
              logger.error("FCM send failed (scheduledRule)", {
                userId,
                caseId: caseDoc.id,
                ruleId: ruleDoc.id,
                code: err.code,
                message: err.message,
              });
              await handleInvalidToken(userDoc.ref, userId, err);
            }
          }
        }
      }
    }

    logger.info("Run finished", {
      usersChecked: usersSnap.size,
      remindersScanned: scannedReminders,
      rulesScanned: scannedRules,
      sent: sentCount,
    });
  }
);
