import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/const/ble_const.dart';
import 'package:reintechnik/providers/ble_provider.dart';

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: Provider.of<BLEProvider>(context).motorStatus,
        builder: (context, snapshot) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Text(
                    snapshot.data?.getStatus() ?? 'Chưa có thiết bị ghép nối'),
              ),
              Center(
                child: Text("${snapshot.data?.position}/100"),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Provider.of<BLEProvider>(context, listen: false)
                          .controlMotor(ControlType.GO_IN);
                    },
                    child: const Icon(Icons.skip_previous),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Provider.of<BLEProvider>(context, listen: false)
                          .controlMotor(ControlType.STOP);
                    },
                    child: const Icon(Icons.pause),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Provider.of<BLEProvider>(context, listen: false)
                          .controlMotor(ControlType.GO_OUT);
                    },
                    child: const Icon(Icons.skip_next),
                  ),
                ],
              )
            ],
          );
        },
      ),
    );
  }
}
