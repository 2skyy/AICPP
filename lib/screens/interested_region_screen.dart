import 'package:flutter/material.dart';
import '../constants/regions.dart';
import '../theme/toss_colors.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_chip_selector.dart';

class InterestedRegionScreen extends StatefulWidget {
  const InterestedRegionScreen({
    super.key,
    required this.initialRegions,
    required this.homeRegion,
  });

  final List<String> initialRegions;
  final String homeRegion;

  @override
  State<InterestedRegionScreen> createState() => _InterestedRegionScreenState();
}

class _InterestedRegionScreenState extends State<InterestedRegionScreen> {
  late final Set<String> _selected = widget.initialRegions.toSet();

  void _submit() {
    Navigator.of(context).pop(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: const Text('관심지역 관리'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                '관심 있는 지역을 선택해주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: TossColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 32),
              TossChipSelector(
                label: '관심지역 (복수 선택 가능)',
                options: kRegions,
                selected: {..._selected, widget.homeRegion},
                disabled: {widget.homeRegion},
                multiSelect: true,
                onToggle: (value) => setState(() {
                  if (_selected.contains(value)) {
                    _selected.remove(value);
                  } else {
                    _selected.add(value);
                  }
                }),
              ),
              const SizedBox(height: 40),
              TossButton(label: '완료', onPressed: _submit),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
