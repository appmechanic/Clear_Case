import 'package:clearcase/provider/subscription_provider.dart';
import 'package:clearcase/views/insights/insights_screen.dart';
import 'package:clearcase/views/settings/settings_screen.dart';
import 'package:clearcase/views/subscription/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import 'home/calender_screen.dart';

class MainScreen extends StatefulWidget {
  static const String routeName = '/main';
  // Tab indices. The app opens on Insights; flows about a specific date
  // (case setup, reminder taps) open the Calendar.
  static const int insightsTab = 0;
  static const int calendarTab = 1;
  final int index;
  const MainScreen({super.key, required this.index});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  final List<Widget> _children = [
    InsightsScreen(),
    CalenderScreen(),
    SettingsScreen()
  ];

  @override
  Widget build(BuildContext context) {
    // The app needs an active subscription (or free trial) past this point.
    final subscription = context.watch<SubscriptionProvider>();
    if (!subscription.hasAccess) {
      return subscription.isReady
          ? const PaywallScreen()
          : const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          color: AppColors.primary,
          fontSize: 13,
        ),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.primary,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: AppColors.backgroundCards,
        type: BottomNavigationBarType.fixed,
        items: [
          _buildNavItem('assets/icons/insights.svg', 'Insights', MainScreen.insightsTab),
          _buildNavItem('assets/icons/calender.svg', 'Calendar', MainScreen.calendarTab),
          _buildNavItem('assets/icons/settings.svg', 'Settings', 2)
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      String iconPath, String label, int index) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(25),
          color: _currentIndex == index
              ? AppColors.primary
              : Colors.transparent,
        ),
        child: SvgPicture.asset(
          iconPath,
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            _currentIndex == index
                ? AppColors.whiteColor
                : AppColors.primary,
            BlendMode.srcIn,
          ),
        ),
      ),
      label: label,
    );
  }
}