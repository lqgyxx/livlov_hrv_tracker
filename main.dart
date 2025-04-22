
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HRV趋势查看',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HRVHomePage(),
    );
  }
}

class HRVHomePage extends StatefulWidget {
  const HRVHomePage({super.key});
  @override
  State<HRVHomePage> createState() => _HRVHomePageState();
}

class _HRVHomePageState extends State<HRVHomePage> {
  final List<FlSpot> _hrvSpots = [];
  double? _currentHRV;
  BluetoothDevice? _device;

  @override
  void initState() {
    super.initState();
    _startScanAndConnect();
  }

  // 扫描并连接Livlov心率带
  void _startScanAndConnect() async {
    FlutterBlue.instance.startScan(timeout: const Duration(seconds: 4));
    FlutterBlue.instance.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name.contains("Livlov")) {
          await FlutterBlue.instance.stopScan();
          setState(() => _device = r.device);
          await r.device.connect(autoConnect: false);
          _discoverServices(r.device);
          break;
        }
      }
    });
  }

  // 查找服务并监听心率数据
  void _discoverServices(BluetoothDevice device) async {
    var services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          characteristic.value.listen(_handleData);
        }
      }
    }
  }

  // 处理心率数据，解析RR间隔并更新HRV趋势
  void _handleData(List<int> data) {
    if (data.length >= 3) {
      int rr = (data[2] << 8) | data[1];
      double hrv = rr.toDouble();
      setState(() {
        _currentHRV = hrv;
        _hrvSpots.add(FlSpot(_hrvSpots.length.toDouble(), hrv));
        if (_hrvSpots.length > 50) {
          _hrvSpots.removeAt(0); // 限制趋势图数据数量
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HRV趋势图")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 50,
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _hrvSpots,
                      isCurved: true,
                      colors: [Colors.blue],
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            _currentHRV != null
                ? '当前HRV: ${_currentHRV!.toStringAsFixed(2)} ms'
                : '等待数据...'
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _device?.disconnect();
    super.dispose();
  }
}
