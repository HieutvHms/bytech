import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                    snapshot.data?.getStatus() ?? 'Trạng thái chưa xác định'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Icon(Icons.skip_previous),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Icon(Icons.pause),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
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
