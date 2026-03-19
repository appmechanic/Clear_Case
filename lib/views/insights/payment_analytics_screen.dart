import 'package:clearcase/views/insights/payment_detail_screen.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/case_model.dart';
import '../../provider/insight_provider.dart';
import '../../provider/payment_analysis.dart';
import '../widgets/custom_search_box.dart';
import '../widgets/payment_overview_card.dart';


class PaymentAnalyticsScreen extends StatefulWidget {
  static const routeName = '/payment-analytics';
  const PaymentAnalyticsScreen({super.key});

  @override
  State<PaymentAnalyticsScreen> createState() => _PaymentAnalyticsScreenState();
}

class _PaymentAnalyticsScreenState extends State<PaymentAnalyticsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final selectedCase = ModalRoute.of(context)!.settings.arguments as dynamic;
      if (selectedCase != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Set the case in InsightProvider and fetch initial payments
          final insightProv = Provider.of<InsightProvider>(context, listen: false);
          insightProv.setSelectedCase(selectedCase);
          Provider.of<PaymentProvider>(context, listen: false)
              .fetchPaymentsByCase(selectedCase.id);
        });
      }
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
          title: const Text("Payment Analytics", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black)
      ),
      body: Consumer2<InsightProvider, PaymentProvider>(
        builder: (context, insightProv, paymentProv, child) {

          return RefreshIndicator(
            onRefresh: () async {
              if (insightProv.selectedCase != null) {
                await paymentProv.fetchPaymentsByCase(insightProv.selectedCase!.id);
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NEW DROPDOWN SECTION (Same as Insights Screen) ---
                  _buildDropdownSection(insightProv, paymentProv),
                  const SizedBox(height: 20),

                  // Show loader only when fetching new records for a case
                  if (paymentProv.isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 50),
                      child: CircularProgressIndicator(),
                    ))
                  else ...[
                    PaymentOverview(provider: insightProv),
                    const SizedBox(height: 20),
                    CustomSearchBar(
                      controller: _searchController,
                      hintText: "Search by amount, type or method...",
                      onChanged: (value) => paymentProv.filterPayments(value),
                      onClear: () => paymentProv.clearSearch(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Transaction History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.payment, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 15),

                    if (paymentProv.payments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text("No payments found for this case.", style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paymentProv.payments.length,
                        itemBuilder: (context, index) {
                          final record = paymentProv.payments[index];
                          final DateTime? date = record.date;

                          bool showMonthHeader = false;
                          if (date != null) {
                            if (index == 0) showMonthHeader = true;
                            else {
                              final prevDate = paymentProv.payments[index - 1].date;
                              if (prevDate != null && (date.month != prevDate.month || date.year != prevDate.year)) {
                                showMonthHeader = true;
                              }
                            }
                          }

                          final bool isReceived = record.transactionType == "PaymentReceived";
                          final String statusText = isReceived ? "Payment Received" : "Paid by me";
                          final Color statusColor = isReceived ? Colors.green : const Color(0xFF6200EE);
                          final Color categoryColor = (record.paymentCategory == "Compulsory") ? Colors.orange : Colors.green;
                          final bool hasAttachment = record.attachmentUrls != null && record.attachmentUrls!.isNotEmpty;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showMonthHeader) _buildMonthHeader(date!),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, PaymentDetailsScreen.routeName, arguments: record),
                                child: _buildPaymentItem(
                                  date: date != null ? DateFormat('MMM dd').format(date) : "N/A",
                                  title: record.paymentType ?? "General Payment",
                                  status: statusText,
                                  statusColor: statusColor,
                                  amount: "\$${record.amount?.toInt() ?? 0}",
                                  type: record.paymentCategory ?? "Additional",
                                  color: categoryColor,
                                  childName: paymentProv.getChildNamesFromIds(record.childIds, insightProv.selectedCase),
                                  hasAttachment: hasAttachment,
                                ),
                              ),
                            ],
                          );
                        },
                      )
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper for Dropdown to handle case switching and loading
  Widget _buildDropdownSection(InsightProvider insightProv, PaymentProvider paymentProv) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<dynamic>(
        isExpanded: true,
        value: insightProv.selectedCase,
        items: insightProv.allCases.map((caseItem) => DropdownMenuItem<dynamic>(
          value: caseItem,
          child: Text(insightProv.getCaseDisplayName(caseItem), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList(),
        onChanged: (value) {
          insightProv.setSelectedCase(value);
          if (value != null) {
            paymentProv.fetchPaymentsByCase((value as CaseModel).id);
          }
        },
        buttonStyleData: const ButtonStyleData(height: 60, padding: EdgeInsets.zero),
        dropdownStyleData: DropdownStyleData(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(DateFormat('MMMM yyyy').format(date),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildPaymentItem({
    required String date,
    required String title,
    required String status,
    required String amount,
    required String type,
    required String childName,
    required Color statusColor,
    required bool hasAttachment,
    Color color = Colors.orange,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasAttachment)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                        child: const Icon(Icons.attachment, size: 14, color: Color(0xFF6200EE)),
                      ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
                        child: Text(childName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(status, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF212121))),
            ],
          )
        ],
      ),
    );
  }
}