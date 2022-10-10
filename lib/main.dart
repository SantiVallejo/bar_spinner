import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

const Color darkBlue = Color.fromARGB(255, 18, 32, 47);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: darkBlue,
      ),
      debugShowCheckedModeBanner: false,
      home: const SpinnerWheel(),
    );
  }
}

class SpinnerWheel extends StatefulWidget {
  const SpinnerWheel({Key? key}) : super(key: key);

  @override
  SpinnerWheelState createState() => SpinnerWheelState();
}

class SpinnerWheelState extends State<SpinnerWheel> {
  List<Wheel> wheels = [];

  Wheel currWheel = Wheel();

  String currSelected = '';

  bool _isListView = true;
  bool _isSpinning = false;

  late StreamController<int> selected;
  late TextEditingController controller;
  SharedPref sharedPref = SharedPref();

  @override
  void initState() {
    super.initState();

    selected = StreamController<int>.broadcast();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    selected.close();
    controller.dispose();

    super.dispose();
  }

  Future<bool> _loadSavedWheels() async {
    final prefs = await SharedPreferences.getInstance();
    final String wheelsString = prefs.getString('savedWheels') ?? '';
    if (wheelsString != '') {
      wheels = Wheel.decode(wheelsString);
      return true;
    }

    return false;
  }

  Future<void> _saveSavedWheels() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = Wheel.encode(wheels);
    await prefs.setString('savedWheels', encodedData);
  }

  Future<void> _loadBars(String key) async {
    Wheel wheel = Wheel.fromJson(await sharedPref.read(key));

    setState(() {
      currWheel = wheel;
    });
  }

  Future<String?> openDialog() => showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Bar'),
            content: TextField(
              autofocus: true,
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter a bar'),
              onSubmitted: (_) {
                Navigator.of(context).pop(controller.text);
                controller.clear();
              },
            ),
            actions: [
              TextButton(
                child: const Text('Submit'),
                onPressed: () {
                  Navigator.of(context).pop(controller.text);
                  controller.clear();
                },
              ),
            ]),
      );

  void _addNewWheel(String name, List<String> items) {
    final newWheel = Wheel.create(name, items);
    setState(() {
      wheels.add(newWheel);
    });

    sharedPref.save(newWheel.name!, newWheel);
    _saveSavedWheels();
  }

  void _startAddNewWheel(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) {
        return NewWheel(_addNewWheel);
      },
    );
  }

  void _deleteWheel(String name) {
    setState(() {
      wheels.removeWhere((wheel) => wheel.name == name);
    });

    sharedPref.remove(name);
    _saveSavedWheels();
  }

  void _addBar(String bar) async {
    setState(() {
      currWheel.items!.add(bar);
    });

    sharedPref.save(currWheel.name!, currWheel);
  }

  void _deleteBar(String bar) async {
    setState(() {
      currWheel.items!.remove(bar);
    });

    sharedPref.save(currWheel.name!, currWheel);
  }

  void _startEditSlice(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                return Card(
                  elevation: 5,
                  margin:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                  child: ListTile(
                    title: Text(
                      currWheel.items![index],
                    ),
                    trailing: currWheel.items!.length > 2
                        ? IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () {
                              setState(() {
                                _deleteBar(currWheel.items![index]);
                              });
                            })
                        : null,
                  ),
                );
              },
              itemCount: currWheel.items!.length,
            );
          },
        );
      },
    );
  }

  void _updateScreen(bool val, Wheel wheel) {
    _isListView = val;
    currWheel = wheel;
  }

  Widget _buildText() {
    if (_isSpinning) {
      Future.delayed(const Duration(milliseconds: 4600), () {
      setState(() {
        _isSpinning = false;
      });
    });
    }

    return _isSpinning
        ? const CircularProgressIndicator()
        : Text(
            currSelected,
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadSavedWheels(),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        return Scaffold(
          appBar: AppBar(
            leading: !_isListView
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () {
                      setState(() {
                        _isListView = true;
                        currSelected = '';
                      });
                    },
                  )
                : null,
            actions: <Widget>[
              _isListView
                  ? IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _startAddNewWheel(context);
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _startEditSlice(context);
                      },
                    ),
            ],
            title: const Text('Spinner'),
          ),
          body: Center(
            child: _isListView
                ? WheelList(wheels, _loadBars, _updateScreen, _deleteWheel)
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSpinning = true;
                        int index =
                            Fortune.randomInt(0, currWheel.items!.length);
                        currSelected = currWheel.items![index];
                        selected.add(index);
                      });
                    },
                    child: Column(
                      children: [
                        Flexible(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: Align(
                                alignment: Alignment.bottomCenter,
                                child: _buildText()),
                          ),
                        ),
                        Flexible(
                          flex: 4,
                          child: FortuneWheel(
                            selected: selected.stream,
                            items: [
                              for (var item in currWheel.items!)
                                FortuneItem(child: Text(item)),
                            ],
                          ),
                        ),
                        const Flexible(
                          flex: 1,
                          child: SizedBox(),
                        ),
                      ],
                    ),
                  ),
          ),
          floatingActionButton: _isListView
              ? null
              : FloatingActionButton(
                  child: const Icon(Icons.add),
                  onPressed: () async {
                    final item = await openDialog();
                    if (item == null || item.isEmpty) return;

                    _addBar(item);
                  },
                ),
        );
      },
    );
  }
}

class WheelList extends StatelessWidget {
  final Function loadBars;
  final Function updateScreen;
  final Function deleteWheel;

  final List<Wheel> wheels;

  const WheelList(this.wheels, this.loadBars, this.updateScreen, this.deleteWheel, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
            loadBars(wheels[index].name);
            updateScreen(false, wheels[index]);
          },
          child: Card(
            elevation: 5,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
            child: ListTile(
              title: Text(
                wheels[index].name!,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                color: Colors.red,
                onPressed: () => deleteWheel(wheels[index].name),
              ),
            ),
          ),
        );
      },
      itemCount: wheels.length,
    );
  }
}

class NewWheel extends StatelessWidget {
  final Function addWheel;

  final _nameController = TextEditingController();
  final _itemsController = TextEditingController();

  NewWheel(this.addWheel, {Key? key}) : super(key: key);

  void _submitData(BuildContext context) {
    List<String> items = _itemsController.text.split(RegExp(', {0,}'));
    addWheel(_nameController.text, items);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Card(
        elevation: 5,
        child: Container(
          padding: EdgeInsets.only(
            top: 10,
            left: 10,
            right: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
                controller: _nameController,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Items',
                ),
                controller: _itemsController,
              ),
              ElevatedButton(
                onPressed: () => _submitData(context),
                child: const Text(
                  'Add Wheel',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Wheel {
  String? name;
  List<String>? items;

  Wheel();

  Wheel.create(this.name, this.items);

  Map<String, dynamic> toJson() => {
        'name': name,
        'items': items,
      };

  Wheel.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        items = json['items'].cast<String>();

  static Map<String, dynamic> toMap(Wheel wheel) => {
        'name': wheel.name,
        'items': wheel.items,
      };

  static String encode(List<Wheel> wheels) => json.encode(
        wheels
            .map<Map<String, dynamic>>((wheel) => Wheel.toMap(wheel))
            .toList(),
      );

  static List<Wheel> decode(String wheels) =>
      (json.decode(wheels) as List<dynamic>)
          .map<Wheel>((item) => Wheel.fromJson(item))
          .toList();
}

class SharedPref {
  read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return json.decode(prefs.getString(key)!);
  }

  save(String key, value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(key, json.encode(value));
  }

  remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(key);
  }
}
