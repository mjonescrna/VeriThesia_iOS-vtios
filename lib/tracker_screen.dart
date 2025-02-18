import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftDifferentialTracker extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) updateEntries;

  const ShiftDifferentialTracker({super.key, required this.updateEntries});

  @override
  _ShiftDifferentialTrackerState createState() =>
      _ShiftDifferentialTrackerState();
}

class _ShiftDifferentialTrackerState extends State<ShiftDifferentialTracker> {
  final List<Map<String, dynamic>> _entries = [];

  DateTime? _selectedDate;
  String? _selectedTraumaLevel;
  String? _selectedShiftDifferential;
  final TextEditingController _hoursController = TextEditingController();

  /// We changed any int-based 'minHours' or 'hours' to .0 so there's no int/double conflict.
  final Map<String, List<Map<String, dynamic>>> _shiftDifferentials = {
    'Trauma 1': [
      {'name': 'Shift Extension after 15 minutes', 'rate': 30.0},
      {'name': 'Monday-Thursday Night after 1900', 'rate': 35.0},
      {'name': 'Monday-Thursday Nights', 'rate': 25.0},
      {'name': 'Weekend Days', 'rate': 25.0},
      {'name': 'Weekend Nights', 'rate': 45.0},
      {'name': 'Holiday Days', 'rate': 50.0},
      {'name': 'Holiday Nights', 'rate': 70.0},
      {'name': 'Unrestricted Call', 'rate': 350.0, 'hours': 12.0},
      {'name': 'Activated Call', 'rate': 50.0, 'minHours': 2.0},
      {'name': 'Extra Shift', 'rate': 190.0},
    ],
    'Trauma 2, 3, 4': [
      {'name': 'Shift Extension after 15 minutes', 'rate': 30.0},
      {'name': 'Monday-Thursday Night after 1900', 'rate': 15.0},
      {'name': 'Monday-Thursday Nights', 'rate': 15.0},
      {'name': 'Weekend Days', 'rate': 15.0},
      {'name': 'Weekend Nights', 'rate': 15.0},
      {'name': 'Holiday Days', 'rate': 30.0},
      {'name': 'Holiday Nights', 'rate': 50.0},
      {'name': 'Unrestricted Call', 'rate': 250.0, 'hours': 12.0},
      {'name': 'Activated Call', 'rate': 50.0, 'minHours': 2.0},
      {'name': 'Extra Shift', 'rate': 190.0},
    ],
  };

  /// Adds a single entry based on the current fields (date, trauma, shift, hours).
  void _addEntry() {
    if (_selectedDate == null ||
        _selectedTraumaLevel == null ||
        _selectedShiftDifferential == null ||
        _hoursController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields before adding an entry.'),
        ),
      );
      return;
    }

    // Retrieve the shift data
    final shiftData = _shiftDifferentials[_selectedTraumaLevel]!
        .firstWhere((shift) => shift['name'] == _selectedShiftDifferential);

    double inputHours = double.tryParse(_hoursController.text) ?? 0.0;
    double hours = inputHours;
    final double rate = shiftData['rate'] as double;

    bool minApplied = false;
    // If there's a minHours, enforce it
    if (shiftData.containsKey('minHours')) {
      final double minHours = shiftData['minHours'] as double;
      if (hours < minHours) {
        hours = minHours;
        minApplied = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Per CCI policy, you will be awarded a minimum of $minHours hours of pay for this call.',
            ),
          ),
        );
      }
    }

    final double total = rate * hours;

    setState(() {
      _entries.add({
        'date': DateFormat('MM/dd/yyyy').format(_selectedDate!),
        'task': _selectedShiftDifferential!,
        'hours': hours,
        'minApplied': minApplied,
        'total': total,
      });
    });

    widget.updateEntries(_entries);

    // Reset fields after adding
    _selectedDate = null;
    _selectedShiftDifferential = null;
    _hoursController.clear();
  }

  /// Opens a Material date picker and sets _selectedDate
  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Captures new shifts from Qgenda. If any are returned, merges them into _entries.
  Future<void> _openQgendaScreen() async {
    final result = await Navigator.pushNamed(context, '/qgenda');
    if (result is List<Map<String, dynamic>>) {
      setState(() {
        _entries.addAll(result);
        widget.updateEntries(_entries);
      });
    }
  }

  /// Edits an existing entry in _entries.
  void _editEntry(int index) async {
    final entry = _entries[index];
    final currentDate = DateFormat('MM/dd/yyyy').parse(entry['date']);

    // Attempt to match the existing 'task' to a known shift
    String? traumaLevel;
    String? shiftDifferential;
    bool found = false;
    for (final traumaKey in _shiftDifferentials.keys) {
      for (final shift in _shiftDifferentials[traumaKey]!) {
        if (shift['name'] == entry['task']) {
          traumaLevel = traumaKey;
          shiftDifferential = shift['name'];
          found = true;
          break;
        }
      }
      if (found) break;
    }

    traumaLevel ??= 'Trauma 1';
    shiftDifferential ??=
        _shiftDifferentials[traumaLevel]![0]['name'] as String;

    double hours = entry['hours'] as double;
    bool minApplied = entry['minApplied'] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            DateTime tempDate = currentDate;
            String tempTraumaLevel = traumaLevel!;
            String tempShiftDiff = shiftDifferential!;
            double tempHours = hours;

            double computeTotal(String trauma, String shift, double h) {
              final shiftData = _shiftDifferentials[trauma]!.firstWhere(
                (s) => s['name'] == shift,
                orElse: () => {'rate': 0.0},
              );
              final double r = shiftData['rate'] as double;
              return r * h;
            }

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: tempDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setDialogState(() {
                  tempDate = picked;
                });
              }
            }

            return AlertDialog(
              title: const Text('Edit Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MM/dd/yyyy').format(tempDate)),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: pickDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Trauma level
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        "Select Trauma Level",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DropdownButton<String>(
                      value: tempTraumaLevel,
                      isExpanded: true,
                      onChanged: (value) {
                        setDialogState(() {
                          tempTraumaLevel = value!;
                          tempShiftDiff = _shiftDifferentials[tempTraumaLevel]!
                              .first['name'] as String;
                        });
                      },
                      items: _shiftDifferentials.keys.map((trauma) {
                        return DropdownMenuItem<String>(
                          value: trauma,
                          child: Text(trauma),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),

                    // Shift differential
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        "Select Shift Differential",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DropdownButton<String>(
                      value: tempShiftDiff,
                      isExpanded: true,
                      onChanged: (value) {
                        setDialogState(() {
                          tempShiftDiff = value!;
                        });
                      },
                      items: _shiftDifferentials[tempTraumaLevel]!.map((shift) {
                        final name = shift['name'] as String;
                        final rate = shift['rate'] as double;
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text("$name (\$$rate/hr)"),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),

                    // Hours text field
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Enter Hours'),
                      onChanged: (val) {
                        final double h = double.tryParse(val) ?? 0.0;
                        setDialogState(() {
                          tempHours = h;
                        });
                      },
                      controller: TextEditingController(
                        text: tempHours.toString(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Show computed total
                    Text(
                      "Total: \$${computeTotal(tempTraumaLevel, tempShiftDiff, tempHours).toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    final shiftData =
                        _shiftDifferentials[tempTraumaLevel]!.firstWhere(
                      (s) => s['name'] == tempShiftDiff,
                      orElse: () => {'rate': 0.0},
                    );

                    double finalHours = tempHours;
                    bool finalMinApplied = false;
                    if (shiftData.containsKey('minHours')) {
                      final double minHours = shiftData['minHours'] as double;
                      if (finalHours < minHours) {
                        finalHours = minHours;
                        finalMinApplied = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Per CCI policy, you will be awarded a minimum of $minHours hours of pay for this call.',
                            ),
                          ),
                        );
                      }
                    }

                    final double newTotal = computeTotal(
                      tempTraumaLevel,
                      tempShiftDiff,
                      finalHours,
                    );

                    setState(() {
                      _entries[index] = {
                        'date': DateFormat('MM/dd/yyyy').format(tempDate),
                        'task': tempShiftDiff,
                        'hours': finalHours,
                        'minApplied': finalMinApplied,
                        'total': newTotal,
                      };
                    });
                    widget.updateEntries(_entries);
                    Navigator.of(context).pop();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteEntry(int index) {
    setState(() {
      _entries.removeAt(index);
      widget.updateEntries(_entries);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the back arrow so user can't go back to login accidentally
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Shift Differential Tracker'),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/qgenda.png',
              height: 80,
              width: 80,
            ),
            onPressed: _openQgendaScreen,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null
                          ? 'Please select a date'
                          : DateFormat('MM/dd/yyyy').format(_selectedDate!),
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                "Select Trauma Level",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            DropdownButton<String>(
              hint: const Text('Select Trauma Level'),
              value: _selectedTraumaLevel,
              isExpanded: true,
              onChanged: (value) {
                setState(() {
                  _selectedTraumaLevel = value;
                  _selectedShiftDifferential = null;
                });
              },
              items: _shiftDifferentials.keys.map((trauma) {
                return DropdownMenuItem<String>(
                  value: trauma,
                  child: Text(trauma),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                "Select Shift Differential",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (_selectedTraumaLevel != null)
              DropdownButton<String>(
                hint: const Text('Select Shift Differential'),
                value: _selectedShiftDifferential,
                isExpanded: true,
                onChanged: (value) {
                  setState(() {
                    _selectedShiftDifferential = value;
                  });
                },
                items: _shiftDifferentials[_selectedTraumaLevel]!.map((shift) {
                  final name = shift['name'] as String;
                  final rate = shift['rate'] as double;
                  final hoursInfo = shift.containsKey('hours')
                      ? ', ${shift['hours']} hr shift'
                      : '';
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text('$name (\$$rate/hr$hoursInfo)'),
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _hoursController,
              decoration: const InputDecoration(labelText: 'Enter Hours'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _addEntry,
                  child: const Text('Add Entry'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/reports');
                  },
                  child: const Text('My Reports'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final hoursDisplay = entry['minApplied'] == true
                      ? '*${entry['hours']} hrs'
                      : '${entry['hours']} hrs';

                  return ListTile(
                    title: Text(
                      '${entry['task']} - \$${entry['total'].toStringAsFixed(2)}',
                    ),
                    subtitle: Text(
                      'Date: ${entry['date']} | Hours: $hoursDisplay',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editEntry(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteEntry(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
