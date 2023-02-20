import 'package:flutter/material.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/screens/controller/controller_screen.dart';
import 'package:reintechnik/screens/home/home_screen.dart';
import 'package:reintechnik/screens/screne/screne_screen.dart';
import 'package:reintechnik/screens/setting/setting_screen.dart';

const screenList = [
  HomeScreen(),
  ControllerScreen(),
  ScreneScreen(),
  SettingScreen()
];

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  @override
  void initState() {
    super.initState();
  }

  int currentTab = 1;

  void changeTab(int tabIndex) {
    currentTab = tabIndex;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screenList[currentTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: CustomColor.stateGreen,
        unselectedItemColor: CustomColor.neutralBlack,
        onTap: changeTab,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pest_control_rodent_outlined),
            label: 'Controller',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.screen_share_sharp),
            label: 'Screne',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Setting',
          ),
        ],
      ),
    );
  }
}
