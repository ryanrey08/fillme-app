import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../services/driver_service.dart';

// Provider to load schedule
final scheduleProvider = FutureProvider.autoDispose<WorkSchedule>((ref) async {
  final driverService = ref.read(driverServiceProvider);
  return await driverService.getSchedule();
});

class WorkScheduleScreen extends ConsumerStatefulWidget {
  const WorkScheduleScreen({super.key});

  @override
  ConsumerState<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends ConsumerState<WorkScheduleScreen> {
  Map<String, _DaySchedule>? _schedule;
  bool _isSaving = false;
  bool _hasChanges = false;

  void _initializeSchedule(WorkSchedule apiSchedule, {bool force = false}) {
    if (_schedule != null && !force) return; // Already initialized
    
    _schedule = {
      'Monday': _DaySchedule.fromApi(apiSchedule.schedule['monday']!),
      'Tuesday': _DaySchedule.fromApi(apiSchedule.schedule['tuesday']!),
      'Wednesday': _DaySchedule.fromApi(apiSchedule.schedule['wednesday']!),
      'Thursday': _DaySchedule.fromApi(apiSchedule.schedule['thursday']!),
      'Friday': _DaySchedule.fromApi(apiSchedule.schedule['friday']!),
      'Saturday': _DaySchedule.fromApi(apiSchedule.schedule['saturday']!),
      'Sunday': _DaySchedule.fromApi(apiSchedule.schedule['sunday']!),
    };
  }

  Future<void> _saveSchedule() async {
    if (_schedule == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final driverService = ref.read(driverServiceProvider);
      final scheduleData = <String, DaySchedule>{
        'monday': _schedule!['Monday']!.toDaySchedule(),
        'tuesday': _schedule!['Tuesday']!.toDaySchedule(),
        'wednesday': _schedule!['Wednesday']!.toDaySchedule(),
        'thursday': _schedule!['Thursday']!.toDaySchedule(),
        'friday': _schedule!['Friday']!.toDaySchedule(),
        'saturday': _schedule!['Saturday']!.toDaySchedule(),
        'sunday': _schedule!['Sunday']!.toDaySchedule(),
      };
      
      // Get updated schedule from API response
      final updatedSchedule = await driverService.updateSchedule(scheduleData);
      
      // Invalidate the provider to refresh data across all screens
      ref.invalidate(scheduleProvider);
      
      if (mounted) {
        // Force reinitialize with the returned data
        _initializeSchedule(updatedSchedule, force: true);
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final scheduleAsync = ref.watch(scheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Schedule'),
        backgroundColor: AppColors.driverColor,
        foregroundColor: AppColors.white,
        actions: [
          if (_hasChanges)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveSchedule,
                    tooltip: 'Save Schedule',
                  ),
        ],
      ),
      body: scheduleAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.driverColor),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to load schedule',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(scheduleProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.driverColor,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (schedule) {
          _initializeSchedule(schedule);
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.driverColor,
                      AppColors.driverColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.isOnline == true ? 'Currently Online' : 'Currently Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set your availability for deliveries',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Weekly Schedule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Weekly Schedule',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_hasChanges)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Unsaved changes',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Configure your working hours for each day',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Schedule Days
              ..._schedule!.entries.map((entry) => _ScheduleDayTile(
                    day: entry.key,
                    schedule: entry.value,
                    onChanged: (newSchedule) {
                      setState(() {
                        _schedule![entry.key] = newSchedule;
                        _hasChanges = true;
                      });
                    },
                  )),

              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.select_all,
                      label: 'Enable All',
                      onTap: () {
                        setState(() {
                          for (var key in _schedule!.keys) {
                            _schedule![key] = _DaySchedule(
                              isEnabled: true,
                              startTime: _schedule![key]!.startTime,
                              endTime: _schedule![key]!.endTime,
                            );
                          }
                          _hasChanges = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.deselect,
                      label: 'Disable All',
                      onTap: () {
                        setState(() {
                          for (var key in _schedule!.keys) {
                            _schedule![key] = _DaySchedule(
                              isEnabled: false,
                              startTime: _schedule![key]!.startTime,
                              endTime: _schedule![key]!.endTime,
                            );
                          }
                          _hasChanges = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.work,
                      label: 'Weekdays Only',
                      onTap: () {
                        setState(() {
                          final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
                          for (var key in _schedule!.keys) {
                            _schedule![key] = _DaySchedule(
                              isEnabled: weekdays.contains(key),
                              startTime: _schedule![key]!.startTime,
                              endTime: _schedule![key]!.endTime,
                            );
                          }
                          _hasChanges = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.weekend,
                      label: 'Weekends Only',
                      onTap: () {
                        setState(() {
                          final weekends = ['Saturday', 'Sunday'];
                          for (var key in _schedule!.keys) {
                            _schedule![key] = _DaySchedule(
                              isEnabled: weekends.contains(key),
                              startTime: _schedule![key]!.startTime,
                              endTime: _schedule![key]!.endTime,
                            );
                          }
                          _hasChanges = true;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasChanges && !_isSaving ? _saveSchedule : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.driverColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DaySchedule {
  final bool isEnabled;
  final String startTime;
  final String endTime;

  _DaySchedule({
    required this.isEnabled,
    required this.startTime,
    required this.endTime,
  });

  factory _DaySchedule.fromApi(DaySchedule api) {
    return _DaySchedule(
      isEnabled: api.isEnabled,
      startTime: api.startTime,
      endTime: api.endTime,
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'enabled': isEnabled,
      'start': startTime,
      'end': endTime,
    };
  }

  DaySchedule toDaySchedule() {
    return DaySchedule(
      isEnabled: isEnabled,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

class _ScheduleDayTile extends StatelessWidget {
  final String day;
  final _DaySchedule schedule;
  final ValueChanged<_DaySchedule> onChanged;

  const _ScheduleDayTile({
    required this.day,
    required this.schedule,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: schedule.isEnabled
              ? AppColors.driverColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: schedule.isEnabled ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              Switch(
                value: schedule.isEnabled,
                onChanged: (value) {
                  onChanged(_DaySchedule(
                    isEnabled: value,
                    startTime: schedule.startTime,
                    endTime: schedule.endTime,
                  ));
                },
                activeColor: AppColors.driverColor,
              ),
            ],
          ),
          if (schedule.isEnabled) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Start',
                    time: schedule.startTime,
                    onTap: () => _selectTime(context, true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.grey[400],
                  ),
                ),
                Expanded(
                  child: _TimeButton(
                    label: 'End',
                    time: schedule.endTime,
                    onTap: () => _selectTime(context, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final parts = (isStart ? schedule.startTime : schedule.endTime).split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.driverColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final newTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onChanged(_DaySchedule(
        isEnabled: schedule.isEnabled,
        startTime: isStart ? newTime : schedule.startTime,
        endTime: isStart ? schedule.endTime : newTime,
      ));
    }
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.driverColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: AppColors.driverColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.driverColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
