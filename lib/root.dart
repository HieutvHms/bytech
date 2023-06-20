import 'package:flutter/material.dart';
import 'package:reintechnik/const/asset_const.dart';
import 'package:reintechnik/const/custom_color.dart';
import 'package:reintechnik/new_screen/connect_screen.dart';
import 'package:reintechnik/new_screen/home/home_screen.dart';
import 'package:reintechnik/new_screen/personal/profile_screen.dart';

final screenList = [
  const NewHomeScreen2(),
  const ConnectScreen(),
  const ProfileScreen(),
];
final GlobalKey<NavigatorState> globalKey = GlobalKey<NavigatorState>();

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
    return SafeArea(
      child: Scaffold(
        key: globalKey,
        body: screenList[currentTab],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentTab,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: CustomColor.primaryColor,
          unselectedItemColor: CustomColor.neutralBlack,
          onTap: changeTab,
          items: const [
            BottomNavigationBarItem(
              icon: ImageIcon(AssetImage(AssetConst.homeIcon)),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: ImageIcon(AssetImage(AssetConst.connectIcon)),
              label: 'Connect',
            ),
            BottomNavigationBarItem(
              icon: ImageIcon(AssetImage(AssetConst.profileIcon)),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
