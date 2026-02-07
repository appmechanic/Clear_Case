import 'package:clearcase/views/insights/insights_screen.dart';
import 'package:clearcase/views/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../core/theme/app_colors.dart';
import 'home/calender_screen.dart';

class MainScreen extends StatefulWidget {
  static const String routeName = '/main';
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
    CalenderScreen(),
    InsightsScreen(),
    SettingsScreen()
  ];

  @override
  Widget build(BuildContext context) {
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
          _buildNavItem('assets/icons/calender.svg', 'Calender', 0),
          _buildNavItem('assets/icons/insights.svg', 'Insights', 1),
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