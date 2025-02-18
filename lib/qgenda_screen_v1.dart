import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class QgendaIntegrationNew extends StatefulWidget {
  const QgendaIntegrationNew({super.key});

  @override
  _QgendaIntegrationNewState createState() => _QgendaIntegrationNewState();
}

class _QgendaIntegrationNewState extends State<QgendaIntegrationNew> {
  String? _icalUrl; // Persisted calendar URL
  final TextEditingController _urlController = TextEditingController();

  /// We now store a single date range (instead of separate start/end).
  DateTimeRange? _selectedDateRange;

  bool isLoading = false;
  String? errorMessage;
  List<Map<String, dynamic>> newEntries = [];

  final Map<String, List<Map<String, dynamic>>> _shiftDifferentials = {
    'Trauma 1': [
      {'name': 'Shift Extension after 15 minutes', 'rate': 30.0},
      {'name': 'Monday-Thursday Night after 1900', 'rate': 35.0},
      {'name': 'Monday-Thursday Nights', 'rate': 25.0},
      {'name': 'Weekend Days', 'rate': 25.0},
      {'name': 'Weekend Nights', 'rate': 45.0},
      {'name': 'Holiday Days', 'rate': 50.0},
      {'name': 'Holiday Nights', 'rate': 70.0},
      {'name': 'Unrestricted Call', 'rate': 350.0, 'hours': 12},
      {'name': 'Activated Call', 'rate': 50.0, 'minHours': 2},
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
      {'name': 'Unrestricted Call', 'rate': 250.0, 'hours': 12},
      {'name': 'Activated Call', 'rate': 50.0, 'minHours': 2},
      {'name': 'Extra Shift', 'rate': 190.0},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadIcalUrl();
  }

  /// Helper function: Finds the shift object by name across all trauma groups.
  Map<String, dynamic>? _findShiftObject(String taskName) {
    for (final group in _shiftDifferentials.values) {
      for (final shift in group) {
        if (shift['name'] == taskName) {
          return shift;
        }
      }
    }
    return null;
  }

  /// Load any previously saved iCal URL from SharedPreferences.
  Future<void> _loadIcalUrl() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final storedUrl = prefs.getString('icalUrl');
    debugPrint("DEBUG: Loaded stored icalUrl: $storedUrl");
    if (storedUrl != null && storedUrl.isNotEmpty) {
      setState(() {
        _icalUrl = storedUrl;
      });
    }
  }

  /// User pastes their iCal URL and taps Connect.
  Future<void> _connectCalendar() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        errorMessage = "Please enter a Qgenda iCal URL.";
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setString('icalUrl', url);
    debugPrint("DEBUG: Saved icalUrl: $url");

    setState(() {
      _icalUrl = url;
      errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Qgenda calendar connected! Please select a date range.',
        ),
      ),
    );
  }

  /// Let the user pick a date range, just like in reports_screen.dart.
  Future<void> _selectDateRange(BuildContext context) async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 7)),
          ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedRange != null) {
      setState(() {
        _selectedDateRange = pickedRange;
      });
    }
  }

  /// Fetch ICS data, parse events, and create shift entries based on the date range.
  Future<void> _loadShifts() async {
    if (_icalUrl == null || _icalUrl!.isEmpty) {
      debugPrint("DEBUG: _icalUrl is null or empty");
      return;
    }
    if (_selectedDateRange == null) {
      setState(() {
        errorMessage = "Please select a date range first.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      newEntries = [];
    });

    try {
      final response = await http.get(Uri.parse(_icalUrl!));
      if (!mounted) return;
      debugPrint("DEBUG: HTTP response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final icalData = response.body;
        final events = _parseICal(icalData);
        final entries = <Map<String, dynamic>>[];

        final startDate = _selectedDateRange!.start;
        final endDate = _selectedDateRange!.end;

        for (final event in events) {
          final dt = event['dtstart'] as DateTime?;
          if (dt != null) {
            // Include events within the selected date range
            if (!dt.isBefore(startDate) && !dt.isAfter(endDate)) {
              entries.addAll(_processEvent(event));
            }
          }
        }
        debugPrint("DEBUG: Loaded ${entries.length} entries from iCal data");

        setState(() {
          newEntries = entries;
        });
      } else {
        setState(() {
          errorMessage =
              "Failed to load shifts (status: ${response.statusCode}). Please re-enter your Qgenda URL.";
          _icalUrl = null;
          _urlController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Error loading shifts: $e";
        _icalUrl = null;
        _urlController.clear();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Parse the ICS data to extract SUMMARY and DTSTART fields.
  List<Map<String, dynamic>> _parseICal(String data) {
    final events = <Map<String, dynamic>>[];
    final lines = data.split('\n');
    Map<String, dynamic>? currentEvent;

    for (var line in lines) {
      line = line.trim();
      if (line == "BEGIN:VEVENT") {
        currentEvent = {};
      } else if (line == "END:VEVENT") {
        if (currentEvent != null) {
          events.add(currentEvent);
        }
        currentEvent = null;
      } else if (currentEvent != null) {
        if (line.startsWith("SUMMARY:")) {
          currentEvent['summary'] = line.substring("SUMMARY:".length);
        } else if (line.startsWith("DTSTART")) {
          final index = line.indexOf(':');
          if (index != -1) {
            final dateStr = line.substring(index + 1);
            try {
              final dt = DateTime.parse(dateStr);
              currentEvent['dtstart'] = dt;
            } catch (parseError) {
              debugPrint("DEBUG: Error parsing date: $parseError");
            }
          }
        }
      }
    }
    debugPrint("DEBUG: Parsed ${events.length} events from iCal data");
    return events;
  }

  /// Convert event summaries to shift entries, enforcing minHours if applicable.
  List<Map<String, dynamic>> _processEvent(Map<String, dynamic> event) {
    final entries = <Map<String, dynamic>>[];
    final summary = (event['summary'] as String? ?? "").toLowerCase();
    final dtstart = event['dtstart'] as DateTime?;
    if (dtstart == null) return entries;

    final weekday = dtstart.weekday; // Monday=1 ... Sunday=7
    final dateStr = DateFormat('MM/dd/yyyy').format(dtstart);

    void addEntry(String task, double hours, double rate) {
      double finalHours = hours;
      final shiftObj = _findShiftObject(task);
      if (shiftObj != null && shiftObj.containsKey('minHours')) {
        final minH = shiftObj['minHours'] as double;
        if (finalHours < minH) {
          finalHours = minH;
        }
      }
      entries.add({
        'date': dateStr,
        'task': task,
        'hours': finalHours,
        'total': rate * finalHours,
      });
    }

    // Example substring-based logic. Add more as needed:
    if (summary.contains("activated call")) {
      addEntry("Activated Call", 1.0, 50.0);
    }
    if (summary.contains("tr 24") &&
        summary.contains("sah") &&
        summary.contains("crna")) {
      if (weekday >= 1 && weekday <= 4) {
        addEntry("Monday-Thursday Night after 1900", 12, 35);
      } else if (weekday >= 5 && weekday <= 7) {
        addEntry("Weekend Nights", 12, 45);
      }
    }
    // ...the rest of your substring checks remain the same...
    else if (summary.contains("7-23") &&
        summary.contains("sah") &&
        summary.contains("crna")) {
      if (weekday >= 1 && weekday <= 4) {
        addEntry("Monday-Thursday Night after 1900", 4, 35);
      } else if (weekday == 5) {
        addEntry("Weekend Nights", 4, 45);
      }
    } else if (summary.contains("7-21") &&
        summary.contains("sah") &&
        summary.contains("crna")) {
      if (weekday >= 1 && weekday <= 4) {
        addEntry("Monday-Thursday Night after 1900", 2, 35);
      } else if (weekday == 5) {
        addEntry("Weekend Nights", 2, 45);
      }
    } else if (summary.contains("th 9-21") &&
        summary.contains("sah") &&
        summary.contains("crna")) {
      if (weekday == 4) {
        addEntry("Monday-Thursday Night after 1900", 2, 35);
      }
    } else if (summary.contains("tr 15-7") &&
        summary.contains("sah") &&
        summary.contains("crna")) {
      if (weekday >= 1 && weekday <= 4) {
        addEntry("Monday-Thursday Night after 1900", 12, 35);
      } else if (weekday >= 5 && weekday <= 7) {
        addEntry("Weekend Days", 4, 25);
        addEntry("Weekend Nights", 12, 45);
      }
    } else if (summary.contains("tr 23-7") &&
        summary.contains("sah") &&
        summary.contains("crna")) {
      if (weekday >= 1 && weekday <= 4) {
        addEntry("Monday-Thursday Night after 1900", 8, 35);
      } else if (weekday == 5) {
        addEntry("Weekend Nights", 8, 45);
      }
    } else if (summary.contains("tr 19-7") &&
        summary.contains("sah") &&
        summary.contains("crna")) {
      if (weekday >= 1 && weekday <= 4) {
        addEntry("Monday-Thursday Night after 1900", 12, 35);
      } else if (weekday == 5) {
        addEntry("Weekend Nights", 12, 45);
      }
    } else if (summary.contains("w sah 7-15") && summary.contains("crna")) {
      if (weekday == 6 || weekday == 7) {
        addEntry("Weekend Days", 8, 25);
      }
    } else if (summary.contains("w sah 7-19") && summary.contains("crna")) {
      if (weekday == 6 || weekday == 7) {
        addEntry("Weekend Days", 12, 25);
      }
    }

    return entries;
  }

  /// Let the user edit an existing entry in newEntries.
  void _editEntry(int index) async {
    final entry = newEntries[index];
    final parsedDate = DateFormat('MM/dd/yyyy').parse(entry['date']);
    double tempHours = entry['hours'] as double;
    String tempTask = entry['task'];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            DateTime localDate = parsedDate;
            String localTask = tempTask;
            double localHours = tempHours;

            double computeTotal(String task, double hrs) {
              final shiftObj = _findShiftObject(task);
              final rate = shiftObj?['rate'] ?? 0.0;
              if (shiftObj != null && shiftObj.containsKey('minHours')) {
                final minH = shiftObj['minHours'] as double;
                if (hrs < minH) {
                  hrs = minH;
                }
              }
              return rate * hrs;
            }

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: localDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  localDate = picked;
                });
              }
            }

            final allShiftNames = _shiftDifferentials.values
                .expand((group) => group.map((s) => s['name'] as String))
                .toList();

            return AlertDialog(
              title: const Text("Edit Shift Entry"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MM/dd/yyyy').format(localDate)),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: pickDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: localTask,
                      isExpanded: true,
                      onChanged: (value) {
                        setDialogState(() {
                          localTask = value!;
                        });
                      },
                      items: allShiftNames.map((shiftName) {
                        return DropdownMenuItem<String>(
                          value: shiftName,
                          child: Text(shiftName),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Enter Hours'),
                      onChanged: (val) {
                        final h = double.tryParse(val) ?? 0.0;
                        setDialogState(() {
                          localHours = h;
                        });
                      },
                      controller: TextEditingController(
                        text: localHours.toString(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Total: \$${computeTotal(localTask, localHours).toStringAsFixed(2)}",
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
                    final shiftObj = _findShiftObject(localTask);
                    double finalHours = localHours;
                    if (shiftObj != null && shiftObj.containsKey('minHours')) {
                      final minH = shiftObj['minHours'] as double;
                      if (finalHours < minH) {
                        finalHours = minH;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Minimum pay awarded: $minH hrs for $localTask.',
                            ),
                          ),
                        );
                      }
                    }
                    final finalTotal =
                        (shiftObj?['rate'] as double) * finalHours;
                    setState(() {
                      newEntries[index] = {
                        'date': DateFormat('MM/dd/yyyy').format(localDate),
                        'task': localTask,
                        'hours': finalHours,
                        'total': finalTotal,
                      };
                    });
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

  @override
  Widget build(BuildContext context) {
    debugPrint("DEBUG: Building QgendaIntegrationNew with _icalUrl=$_icalUrl");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Qgenda'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: (_icalUrl == null || _icalUrl!.isEmpty)
            ? _buildInitialSetup()
            : _buildDateRangeUI(),
      ),
    );
  }

  /// Screen for user to paste their iCal URL.
  Widget _buildInitialSetup() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (errorMessage != null) ...[
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'To connect your Qgenda calendar, paste your iCal URL below:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Paste Qgenda iCal URL here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _connectCalendar,
            child: const Text('Connect Calendar'),
          ),
        ],
      ),
    );
  }

  /// Screen that lets the user pick a date range, load shifts, and confirm them.
  Widget _buildDateRangeUI() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select a date range to pull your Qgenda shifts:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),

          // This container mimics the date range UI in reports_screen.
          GestureDetector(
            onTap: () => _selectDateRange(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDateRange == null
                        ? 'Please select a date range'
                        : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (errorMessage != null)
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading ? null : _loadShifts,
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text('Load Shifts'),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: newEntries.isEmpty
                ? const Center(
                    child: Text('No shifts found for the selected date range.'),
                  )
                : ListView.builder(
                    itemCount: newEntries.length,
                    itemBuilder: (context, index) {
                      final entry = newEntries[index];
                      return Card(
                        child: ListTile(
                          title: Text('${entry['task']}'),
                          subtitle: Text(
                            'Date: ${entry['date']} - Hours: ${entry['hours']}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${entry['total'].toStringAsFixed(2)}  ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editEntry(index),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    newEntries.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (newEntries.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                // Return these new entries to the previous screen
                Navigator.of(context).pop(newEntries);
              },
              child: const Text('Confirm All'),
            ),
        ],
      ),
    );
  }
}
