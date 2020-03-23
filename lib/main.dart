import "package:flutter/material.dart";
import "dart:io";
import "dart:convert";
import "package:local_database/local_database.dart";
import "package:http/http.dart" as http;
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:path_provider/path_provider.dart";
import "package:flutter/services.dart";
import "dart:async";
import "dart:math";
import "package:flutter_slidable/flutter_slidable.dart";
import "package:in_app_purchase/in_app_purchase.dart";
import "package:permission_handler/permission_handler.dart";
import "package:flutter_udid/flutter_udid.dart";
import 'package:url_launcher/url_launcher.dart';
import "package:firebase_dynamic_links/firebase_dynamic_links.dart";
import "package:after_layout/after_layout.dart";
import "package:super_tooltip/super_tooltip.dart";
import "package:transparent_image/transparent_image.dart";
import 'package:flutter/gestures.dart';
import "package:local_auth/local_auth.dart";
import "key.dart";

String _server;
String _secretKey;

Map<String,dynamic> _userData;
String _userId;
dynamic _externalUserId;
dynamic _internalUserId;

ScrollController _s = new ScrollController();

List<ProductDetails> _products = new List<ProductDetails>();

bool _available = false;

bool _isSubbed;

bool _validDevice = true;

String _deviceId;

bool _isAdmin;

String _currentEmail;

Color _snackBarColor = Colors.grey[800];

Duration _snackBarDuration = const Duration(milliseconds: 1000);

bool _agreedToPolicy;

void _setUserId(String id) async{
  _internalUserId["userId"] = id;
  _userId = id;
  if(id!=null&&id.length>0){
    if(Platform.isIOS){
      _externalUserId.write(key: "PPwnedUserID", value: id);
    }else{
      _externalUserId.writeAsStringSync(id);
    }
  }else{
    if(Platform.isIOS){
      _externalUserId.delete(key: "PPwnedUserID");
    }else{
      _externalUserId.deleteSync(recursive: true);
    }
  }
}

Future<Null> _getUserId() async{
  return new Future<Null>(() async{
    _userId = null;
    _internalUserId = new Database((await getApplicationDocumentsDirectory()).path+"/data");
    String externalUID;
    String internalUID = await _internalUserId["userId"];
    if(Platform.isIOS){
      _externalUserId = new FlutterSecureStorage();
      externalUID = await _externalUserId.read(key: "PPwnedUserID");
      if(externalUID==null&&internalUID!=null){
        _externalUserId.write(key: "PPwnedUserID", value: internalUID);
        externalUID = internalUID;
      }
    }else{
      _externalUserId = new File("/storage/emulated/0/Android/data/.pwnedfig.plist")..createSync(recursive: true);
      String temp = _externalUserId.readAsStringSync();
      if(temp!=null&&temp.length!=0){
        externalUID = temp;
      }else if(internalUID!=null){
        _externalUserId.writeAsStringSync(internalUID);
        externalUID = internalUID;
      }
    }
    if(externalUID==null){
      var response = (await http.get(_server+"/createUser?key="+_secretKey));
      if(response.statusCode==403){
        _runErrorApp();
        throw new Exception("Forbidden");
      }
      externalUID = response.body;
      _internalUserId["userId"] = externalUID;
      if(Platform.isIOS){
        _externalUserId.write(key: "PPwnedUserID", value: externalUID);
      }else{
        _externalUserId.writeAsStringSync(externalUID);
      }
    }else if(internalUID==null){
      _internalUserId["userId"] = externalUID;
    }
    _userId = externalUID;
  });
}

Future<void> _runErrorApp([String message, Brightness brightness]) async{
  return runApp(
      new MaterialApp(
          theme: new ThemeData(
              brightness: brightness
          ),
          home: new Scaffold(
              body: new Container(
                  child: new Center(
                      child: new Text(message??"Something is wrong")
                  )
              )
          ),
          debugShowCheckedModeBanner: false
      )
  );
}

int _permsCount = 0;

bool _canLeave = true;

void main() async{
  if([_server,_secretKey].contains(null)&&![server,secretKey].contains(null)){
    _server = server;
    _secretKey = secretKey;
    server = null;
    secretKey = null;
  }
  if(Platform.isIOS){
    SystemChrome.setEnabledSystemUIOverlays([]);
    await _runErrorApp("",Brightness.dark);
    LocalAuthentication localAuth = new LocalAuthentication();
    bool auth = true;
    while(!auth){
      try{
        auth = await localAuth.authenticateWithBiometrics(localizedReason: "To ensure you are the owner of this phone");
      }catch(e){
        return _runErrorApp();
      }
    }
  }
  if(Platform.isAndroid){
    int count = 0;
    bool hasPerms = (await PermissionHandler().checkPermissionStatus(PermissionGroup.storage))==PermissionStatus.granted;
    while(!hasPerms){
      hasPerms = (await PermissionHandler().requestPermissions([PermissionGroup.storage]))[PermissionGroup.storage]==PermissionStatus.granted;
      if(++count==10&&!hasPerms){
        runApp(new MaterialApp(home:new Scaffold(body:new Builder(builder:(context)=>new Container(child:new Center(child:new Column(mainAxisAlignment: MainAxisAlignment.center,children:[new Padding(padding: EdgeInsets.only(left:MediaQuery.of(context).size.width*.25,right:MediaQuery.of(context).size.width*.25),child:new FittedBox(fit: BoxFit.scaleDown,child:new Text("Please grant storage permssions",style:new TextStyle(fontSize:10000.0)))),new RaisedButton(child:new Text("Grant Permissions"),onPressed: (){
          PermissionHandler().openAppSettings();
          waitForPerms(int count) async{
            if(!hasPerms&&(await PermissionHandler().checkPermissionStatus(PermissionGroup.storage))==PermissionStatus.granted){
              hasPerms = true;
              main();
              return;
            }
            if(count==_permsCount){
              new Timer(new Duration(seconds:1),(){
                waitForPerms(count);
              });
            }
          }
          waitForPerms(++_permsCount);
        })])))))));
        return;
      }
    }
  }
  await _getUserId();
  http.Response response;
  int count = 0;
  do{
    response = await http.get(_server+"/getUserData?user=$_userId&key=$_secretKey");
    if(response.statusCode==403){
      return _runErrorApp();
    }
    if(response.statusCode!=200){
      if(count<2){
        _setUserId(count==0?await _internalUserId["userId"]:null);
        if(count==1){
          await _getUserId();
        }
      }else{
        return _runErrorApp();
      }
    }else{
      _userData = json.decode(response.body);
      _deviceId = await FlutterUdid.udid;
      _userData["devices"] ??= new List<dynamic>();
      if(!_userData["devices"].contains(_deviceId)){
        if(_userData["devices"].length==3){
          _validDevice = false;
        }else{
          await http.get(_server+"/registerDevice?user=$_userId&device=$_deviceId&key=$_secretKey");
          _userData["devices"].add(_deviceId);
        }
      }
      _isSubbed = _userData["sub"]!=null;
      _userData["history"] ??= new List<dynamic>();
      _userData["unlocked"] ??= new List<dynamic>();
      _isAdmin = _userData["admin"]==true;
      _userData["unlocking"] ??= new Map<String,dynamic>();
      _agreedToPolicy = _userData["created"]!=_userData["lastLogin"]||_changingId;
      //print(_userId);
      //print(_userData);
      if(!_changingId){
        runApp(_agreedToPolicy?new App():new UserAgreement());
      }else{
        _changingId = false;
      }
      return;
    }
    ++count;
  }while(response.statusCode!=200);
}

class UserAgreement extends StatefulWidget{
  @override
  _UserAgreementState createState() => new _UserAgreementState();
}

class _UserAgreementState extends State<UserAgreement>{

  @override
  void initState(){
    super.initState();
    precacheImage(new AssetImage("images/logoRound.png"),context);
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Builder(builder:(context){
        double heightOrWidth = min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height);
        double ratio = max(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)/568.0;
        bool landscape = MediaQuery.of(context).size.width>MediaQuery.of(context).size.height;
        List<Widget> widgets = [
          new Container(height:landscape?20.0*ratio:0.0),
          new Container(
              width: heightOrWidth*1/2,
              height: heightOrWidth*1/2,
              child: new FadeInImage(
                  placeholder: new MemoryImage(kTransparentImage),
                  image: new AssetImage("images/logoRound.png"),
                  fadeInDuration: new Duration(milliseconds:  400)
              )
          ),
          new Container(height:landscape?20.0*ratio:0.0),
          new Text("Hi there!",style:new TextStyle(fontSize:25.0*ratio),textAlign: TextAlign.center),
          new Text("Welcome to GetPass.",style: new TextStyle(fontSize:25.0*ratio),textAlign: TextAlign.center),
          new Container(height:landscape?20.0*ratio:0.0),
          new Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:new Text("GetPass provides a completely anonymous and ad-free experience.",style:new TextStyle(fontSize:15.0*ratio,color:Colors.white.withOpacity(0.9)),textAlign: TextAlign.center)),
          new Container(height:landscape?40.0*ratio:0.0),
          new Column(
              children:[
                new Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:new Center(child:new RichText(
                    textAlign:TextAlign.center,
                    text:new TextSpan(
                        children:[
                          new TextSpan(
                            text:"By pressing the \"Get started\" button and using GetPass, you agree to our ",
                            style: new TextStyle(fontSize:9.0*ratio),
                          ),
                          new TextSpan(
                            text:"Privacy Policy",
                            style: new TextStyle(color: Colors.blue,fontSize:9.0*ratio),
                            recognizer: new TapGestureRecognizer()..onTap = () async{
                              if(await canLaunch("https://platypuslabs.llc/privacypolicy")){
                                await launch("https://platypuslabs.llc/privacypolicy");
                              }else{
                                throw "Could not launch";
                              }
                            },
                          ),
                          new TextSpan(
                            text:" and ",
                            style: new TextStyle(fontSize:9.0*ratio),
                          ),
                          new TextSpan(
                            text:"Terms of Use",
                            style: new TextStyle(color: Colors.blue,fontSize:9.0*ratio),
                            recognizer: new TapGestureRecognizer()..onTap = () async{
                              if(await canLaunch("https://platypuslabs.llc/terms")){
                                await launch("https://platypuslabs.llc/terms");
                              }else{
                                throw "Could not launch";
                              }
                            },
                          ),
                          new TextSpan(
                              text:".",
                              style: new TextStyle(fontSize:9.0)
                          ),
                        ]
                    )
                ))),
                new Container(height:10*ratio),
                new Padding(padding:EdgeInsets.only(left:MediaQuery.of(context).size.width/20.0,right:MediaQuery.of(context).size.width/20.0),child:new Container(width:double.infinity,child:new RaisedButton(
                    padding: EdgeInsets.all(13.0),
                    color:Colors.white30,
                    child:new Text("Get started",style:new TextStyle(fontSize:12.0*ratio)),
                    onPressed:(){
                      setState((){
                        _agreedToPolicy=true;
                      });
                      runApp(new App());
                    }
                )))
              ]
          ),
          new Container(height:landscape?50.0*ratio:0.0),
        ];
        return new Scaffold(body:new Container(child:new Center(child:!landscape?new Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children:widgets):new ListView(children:widgets))));
      }),
      theme: new ThemeData.dark(),
      debugShowCheckedModeBanner: false,
    );
  }
}

bool _changingId = false;

int _index = 0;

bool _loading = false;

bool _displayed = false;

class App extends StatefulWidget{
  @override
  _AppState createState() => new _AppState();
}

class _AppState extends State<App>{

  StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  void initState(){
    super.initState();
    precacheImage(new AssetImage("images/logoRound.png"),context);
    InAppPurchaseConnection.instance.isAvailable().then((b) async{
      _available = b;
      if(b){
        _subscription = InAppPurchaseConnection.instance.purchaseUpdatedStream.listen((l) async{
          int i = 0;
          List<PurchaseDetails> newList = new List.from(l);
          newList.removeWhere((d)=>![PurchaseStatus.purchased,PurchaseStatus.error].contains(d.status));
          newList.forEach((details) async{
            if(details.status==PurchaseStatus.purchased){
              if(Platform.isIOS){
                InAppPurchaseConnection.instance.completePurchase(details);
              }else if(Platform.isAndroid){
                InAppPurchaseConnection.instance.consumePurchase(details);
              }
              PurchaseVerificationData data = details.verificationData;
              while(data==null){
                InAppPurchaseConnection.instance.refreshPurchaseVerificationData();
                data = details.verificationData;
              }
              String token = data.serverVerificationData;
              String platform = Platform.isIOS?"ios":"android";
              String product = details.productID;
              bool valid = false;
              try{
                valid = json.decode((await http.post(Uri.encodeFull(_server+"/handlePurchase?user=$_userId&platform=$platform&product=$product&key=$_secretKey"),body:token)).body);
              }catch(e){}
              //print(valid);
              if(valid){
                setState((){
                  if(product=="unlimited"){
                    _isSubbed = true;
                    _userData["sub"] = {
                      "platform":platform,
                      "token":token
                    };
                  }else if(product=="fivecredits"){
                    _userData["unlocks"]+=5;
                  }else if(product=="credit"){
                    _userData["unlocks"]++;
                  }
                });
              }
            }
            if(_loading==true&&++i==l.length){
              setState((){
                _loading = false;
              });
            }
          });
        });
        final ProductDetailsResponse r = await InAppPurchaseConnection.instance.queryProductDetails(["credit","fivecredits","unlimited"].toSet());
        _products = r.productDetails ?? new List<ProductDetails>();
        if(_index==3&&_products.length>0){
          setState((){});
        }
      }
    });
  }

  @override
  void dispose(){
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return new MaterialApp(
        home: new Builder(
            builder: (context){
              if(!_validDevice&&!_displayed){
                _displayed = true;
                new Future.delayed(Duration.zero,(){
                  showDialog(
                      context: context,
                      builder: (context)=>new WillPopScope(
                        child: new AlertDialog(
                            title: new Text("Sorry"),
                            content: new Text("You have reached the limit of registered devices. Please remove one.")
                        ),
                        onWillPop: ()=>new Future<bool>(()=>false),
                      ),
                      barrierDismissible: false
                  );
                });
              }
              return new Scaffold(
                  resizeToAvoidBottomPadding: true,
                  bottomNavigationBar: new Theme(
                      data: Theme.of(context).copyWith(
                          canvasColor: Theme.of(context).primaryColor.withOpacity(.4)
                      ),
                      child: new BottomNavigationBar(
                          currentIndex: _index,
                          type: BottomNavigationBarType.fixed,
                          items: [
                            new BottomNavigationBarItem(
                              icon: new Icon(Icons.search),
                              title: new Text("Search"),
                            ),
                            new BottomNavigationBarItem(
                              icon: new Icon(Icons.history),
                              title: new Text("History"),
                            ),
                            new BottomNavigationBarItem(
                              icon: new Icon(Icons.lock_open),
                              title: new Text("Unlocked"),
                            ),
                            new BottomNavigationBarItem(
                              icon: new Icon(Icons.shopping_cart),
                              title: new Text("Store"),
                            ),
                            new BottomNavigationBarItem(
                              icon: new Icon(Icons.settings),
                              title: new Text("Settings"),
                            )
                          ],
                          onTap: (i){
                            if(i!=_index&&!_loading&&!_removing&_canLeave){
                              _currentSearch = "";
                              _list = null;
                              _searching = false;
                              setState((){
                                _index = i;
                              });
                            }else if(i==_index&&[1,2].contains(i)){
                              _s.animateTo(0.0, duration: new Duration(milliseconds: 300), curve: Curves.easeOut);
                            }
                          }
                      )
                  ),
                  body: new Builder(
                      builder: (context) => new MainPage()
                  )
              );
            }
        ),
        theme: new ThemeData(
            brightness: Brightness.dark,
            snackBarTheme: new SnackBarThemeData(
                contentTextStyle: new TextStyle(
                    color: Colors.white
                )
            ),
            buttonTheme: new ButtonThemeData(
                colorScheme: Theme.of(context).colorScheme.copyWith(secondary: Colors.cyanAccent)
            )
        ),
        debugShowCheckedModeBanner: false
    );
  }
}

GlobalKey _openedKey;

bool _codePageOpened = false, _firstOne = true;

class MainPage extends StatefulWidget{
  @override
  _MainPageState createState() => new _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver{

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _retrieveDynamicLink();
    _firstOne = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed && !_firstOne){
      Scaffold.of(this.context).removeCurrentSnackBar();
      _retrieveDynamicLink();
    }
  }

  void _retrieveDynamicLink() async{
    if(_codePageOpened&&_loading){
      return;
    }
    await new Future.delayed(new Duration(milliseconds:150));
    BuildContext usedContext = this.context;
    if(_currentEmail!=null){
      _openedKey.currentContext.visitChildElements((e){
        if(e.widget is WillPopScope){
          e.visitChildElements((e){
            if(e.widget is Scaffold){
              e.visitChildElements((e){
                usedContext = e;
              });
            }
          });
        }
      });
    }
    PendingDynamicLinkData linkData;
    try{
      linkData = await FirebaseDynamicLinks.instance.retrieveDynamicLink();
    }catch(e){
      Scaffold.of(usedContext).removeCurrentSnackBar();
      Scaffold.of(usedContext).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text("Something went wrong. Please try again"),duration: _snackBarDuration));
      return;
    }
    if(linkData==null){
      return;
    }
    final Uri deepLink = linkData.link;
    if(deepLink!=null){
      _loading = true;
      String key = deepLink.path.split("/").last;
      String email = _userData["unlocking"][key];
      if(email!=null){
        http.Response r = await http.get(_server+"/endUnlock?user=$_userId&unlockKey=$key&key=$_secretKey");
        if(r.statusCode==200){
          if(_codePageOpened){
            _codePageOpened = false;
            Navigator.of(usedContext).pop();
          }
          _isSubbed = json.decode(r.body);
          _userData["unlocked"].add(email);
          _userData["unlocking"].remove(key);
          if(_index==2&&email.contains(_currentSearch)){
            _list.add(email);
          }
          if(!_isSubbed&&!_isAdmin){
            _userData["unlocks"]--;
          }
          if(_currentEmail==email){
            http.Response r = await http.get(_server+"/getPasswords?email=$email&user=$_userId&fromHis=true&key=$_secretKey");
            if(r.statusCode==200){
              _results = json.decode(r.body);
              _openedKey.currentState.setState((){});
            }else{
              Scaffold.of(usedContext).removeCurrentSnackBar();
              Scaffold.of(usedContext).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text("Something went wrong"),duration: _snackBarDuration));
            }
          }else{
            Scaffold.of(usedContext).removeCurrentSnackBar();
            Scaffold.of(usedContext).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text("Unlocked"),duration: _snackBarDuration));
          }
        }else{
          Scaffold.of(usedContext).removeCurrentSnackBar();
          String errorMessage = r.body=="No Unlocks Left"?"Out of unlocks":"Something went wrong";
          Scaffold.of(usedContext).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text(errorMessage),duration: _snackBarDuration));
        }
      }else{
        Scaffold.of(usedContext).removeCurrentSnackBar();
        Scaffold.of(usedContext).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text("The link you clicked is invalid"),duration: _snackBarDuration));
      }
      _loading = false;
      setState((){});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _index==0?new SearchPage():_index==1?new ListPage(ListName.history):_index==2?new ListPage(ListName.unlocked):_index==3?new StorePage():new SettingsPage();
  }
}

class SearchPage extends StatefulWidget{
  @override
  _SearchPageState createState() => new _SearchPageState();
}

class _SearchPageState extends State<SearchPage>{

  String _input = "";

  String _errorText;

  void open(BuildContext context) async{
    if(_loading){
      return;
    }
    setState((){
      _loading = true;
    });
    RegExp regex = new RegExp(r".+@[^\.@]+\.[^\.@]+");
    if(regex.stringMatch(_input)==_input&&!_input.contains(" ")){
      http.Response response = await http.get(_server+"/getPasswords?email=$_input&user=$_userId&key=$_secretKey");
      //print(response.body);
      if(response.statusCode==200){
        if(_userData["history"]==null){
          _userData["history"] = new List<dynamic>();
        }
        _userData["history"].add(_input);
        _results = json.decode(response.body);
        String input = _input;
        setState((){
          _input = "";
          _c.text = "";
        });
        _openedKey = new GlobalKey();
        Navigator.push(context,new PageRouteBuilder(
            pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
              return new PasswordResults(input);
            },
            transitionDuration: new Duration(milliseconds: 300),
            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child){
              return new FadeTransition(
                  opacity: animation,
                  child: child
              );
            }
        ));
      }else{
        _errorText = "Something went wrong";
      }
    }else if(_input.length!=0){
      _errorText = "Invalid Email";
    }
    setState((){
      _loading = false;
    });
  }

  FocusNode _f = new FocusNode();

  TextEditingController _c = new TextEditingController();

  @override
  Widget build(BuildContext context){
    Size sz = MediaQuery.of(context).size;
    double width = min(sz.height,sz.width)*3/4;
    return new Scaffold(
        floatingActionButton: new FloatingActionButton(
          child: !_loading?new Icon(Icons.search, color:Colors.white):new Container(child:new CircularProgressIndicator(),width:30,height:30),
          onPressed: (){
            _f.unfocus();
            open(context);
          },
          backgroundColor: Colors.blueGrey,
        ),
        body: new LayoutBuilder(
            builder: (context, viewportConstraints)=>new SingleChildScrollView(
                child: new ConstrainedBox(
                    constraints: new BoxConstraints(
                        minHeight: viewportConstraints.maxHeight
                    ),
                    child: new Center(
                        child: new Container(
                            child: new Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  new Container(height:20),
                                  new Container(
                                      width: width*2/3,
                                      height: width*2/3,
                                      child: new FadeInImage(
                                          placeholder: new MemoryImage(kTransparentImage),
                                          image: new AssetImage("images/logoRound.png"),
                                          fadeInDuration: new Duration(milliseconds:400)
                                      )
                                  ),
                                  new Container(height:30.0),
                                  new Container(
                                      width: width,
                                      child: new TextField(
                                          autocorrect: false,
                                          enabled: !_loading,
                                          focusNode: _f,
                                          controller: _c,
                                          onChanged: (s){
                                            _input = s;
                                            if(_errorText!=null){
                                              setState((){
                                                _errorText = null;
                                              });
                                            }
                                          },
                                          onSubmitted: (s){
                                            open(context);
                                          },
                                          decoration: new InputDecoration(
                                              border: new OutlineInputBorder(),
                                              labelText: "Email",
                                              isDense: true,
                                              filled: true,
                                              errorText: _errorText
                                            //suffix: _loading?new Container(width:14.0,height:14.0,child:new CircularProgressIndicator(strokeWidth: 2.5)):new Container(height:0,width:0)
                                          ),
                                          inputFormatters: [new EmailTextFormatter()],
                                          keyboardType: TextInputType.emailAddress
                                      )
                                  ),
                                  new Container(height:20),
                                ]
                            )
                        )
                    )
                )
            )
        )
    );
  }
}

Map<String,dynamic> _results;

class PasswordResults extends StatefulWidget{

  final String _email;

  PasswordResults(this._email) : super(key:_openedKey);

  @override
  _PasswordResultsState createState() => new _PasswordResultsState();
}

class _PasswordResultsState extends State<PasswordResults> with AfterLayoutMixin<PasswordResults>{

  GlobalKey _unlockKey = new GlobalKey();
  bool _shownTip = false;

  @override
  void initState(){
    super.initState();
    _currentEmail = widget._email;
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if(!_shownTip&&_results["unlocked"]==false&&_index==0&&_userData["history"].length==1&&_userData["unlocked"].length==0){
      _shownTip = true;
      var t = new SuperTooltip(
          popupDirection: TooltipDirection.down,
          content: new Material(
            child: new Padding(
                padding: EdgeInsets.all(10.0),
                child: new Text("Tap here to unlock the password${_results["data"]==1?"":"s"} that we found for 1 credit",style: new TextStyle(color:Colors.black,fontSize:15),textAlign:TextAlign.center)
            ),
            color: Colors.grey[300],
          ),
          borderWidth: 0.0,
          backgroundColor: Colors.grey[300]
      );
      t.show(_unlockKey.currentContext);
    }
  }

  Widget build(BuildContext context){
    bool unknownPasswords;
    if(_results!=null&&_results["data"] is List&&_results["data"].length>0){
      unknownPasswords = _results["data"].any((s)=>s.contains("█")==true);
    }
    return new WillPopScope(
        child: new Scaffold(
            appBar: new AppBar(title:new Text(widget._email),actions: [
              new Row(
                  children: [
                    new Text(_userData["unlocks"].toString(),style: new TextStyle(fontSize: 20.0)),
                    new Container(width:3.0),
                    new Icon(Icons.credit_card,size:20.0,color: Colors.white)
                  ]
              ),
              _results!=null&&!_results["unlocked"]?new Builder(
                  builder: (rcontext)=>new IconButton(
                    key: _unlockKey,
                    icon: new Icon(Icons.lock_outline,color:Colors.red),
                    onPressed: () async{
                      if(_loading||_removing||!_canLeave){
                        return;
                      }
                      if(_userData["unlocks"]==0&&!_isSubbed){
                        Navigator.of(context).pop();
                        context.findAncestorStateOfType<_AppState>().setState((){
                          _index = 3;
                        });
                      }else{
                        showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context)=>new AlertDialog(
                                title: new Text("Are you sure?"),
                                content: new Text(_isSubbed?"This is free because you are subscribed":"This will use 1 unlock credit after email verification"),
                                actions: [
                                  new FlatButton(
                                      child: new Text("No"),
                                      onPressed: (){
                                        Navigator.of(context).pop();
                                      }
                                  ),
                                  new FlatButton(
                                      child: new Text("Yes"),
                                      onPressed: () async{
                                        _canLeave = false;
                                        var scafCon = Scaffold.of(rcontext);
                                        setState((){
                                          _loading = true;
                                        });
                                        Navigator.of(context).pop();
                                        http.Response response = await http.get(_server+"/startUnlock?email=${widget._email}&user=$_userId&key=$_secretKey");
                                        setState((){
                                          _loading = false;
                                        });
                                        if(response.statusCode==200){
                                          _userData["unlocking"][response.body] = widget._email;
                                          scafCon.removeCurrentSnackBar();
                                          scafCon.showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text("Email sent to ${widget._email}"),duration: _snackBarDuration));
                                          var usedContext;
                                          _openedKey.currentContext.visitChildElements((e){
                                            if(e.widget is WillPopScope){
                                              e.visitChildElements((e){
                                                if(e.widget is Scaffold){
                                                  e.visitChildElements((e){
                                                    usedContext = e;
                                                  });
                                                }
                                              });
                                            }
                                          });
                                          await new Future.delayed(new Duration(milliseconds:750));
                                          if(!_codePageOpened&&!_userData["unlocked"].contains(widget._email)){
                                            showDialog(
                                                context: usedContext,
                                                barrierDismissible: false,
                                                builder: (context)=>new UnlockDialog()
                                            );
                                          }
                                        }else{
                                          scafCon.removeCurrentSnackBar();
                                          String errorMessage = response.body=="Blacklisted"?"This email is blacklisted":"Something went wrong";
                                          scafCon.showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text(errorMessage),duration: _snackBarDuration));
                                        }
                                        _canLeave = true;
                                      }
                                  )
                                ]
                            )
                        );
                      }
                    },
                  )
              ):new Container(
                  width:48.0,height:48.0,
                  child: _results!=null?new Icon(Icons.lock_open,color:Colors.green):new Icon(Icons.settings)
              )
            ],bottom: _loading&&!_codePageOpened?new PreferredSize(child: new Container(height:2,child:new LinearProgressIndicator()), preferredSize: new Size(double.infinity,2.0)):null),
            body: new Container(
              child: _results!=null&&_results["data"] is List&&_results["data"].length>0?new Column(
                children: [
                  unknownPasswords?new Container(
                    color: Colors.white24,
                    child: new ListTile(
                      title: new Text("Check a password",style:new TextStyle(color: Colors.white, fontSize: 19)),
                      subtitle: new Text("Guess if a password is on this list"),
                      trailing: new Container(
                          child: new Row(
                            children: [
                              new Text("0",style: new TextStyle(fontSize: 19.0)),
                              new Container(width:3),
                              new Icon(Icons.credit_card,size:19.0)
                            ],
                            mainAxisAlignment: MainAxisAlignment.end,
                          ),
                          width: 40.0
                      ),
                      onTap: (){
                        showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context)=>new UnlockPasswordDialog(widget._email)
                        );
                      }
                    )
                  ):new Container(),
                  new Expanded(
                    child: new Scrollbar(
                        child: new ListView.builder(
                            itemBuilder: (context,i)=>new Column(
                                children: _results!=null?[
                                  new ListTile(title: new Text(_results["data"][i])),
                                  i<_results["data"].length-1?new Divider(height:2.0):new Container()
                                ]:[
                                  new ListTile(title:new Text("placeholder")),
                                  new Divider(height:2.0)
                                ]
                            ),
                            physics: new ClampingScrollPhysics(),
                            itemCount: _results["data"].length
                        )
                    )
                  )
                ]
              ):_results!=null&&_results["data"] is int?new Center(
                  child: new Container(
                      width:min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)*.63,
                      child: new FittedBox(
                          fit: BoxFit.fitWidth,
                          child: new Text("${_results["data"]} password${_results["data"]==1?"":"s"} found",style: new TextStyle(color: _results["data"]==0?Colors.green:Colors.red))
                      )
                  )
              ):new Center(child:new Container(
                  width:min(MediaQuery.of(context).size.width,MediaQuery.of(context).size.height)*.55,
                  child: new FittedBox(
                      fit: BoxFit.fitWidth,
                      child: new Text("No Results Yet")
                  )
              )),
            )
        ),
        onWillPop:(){
          if(!_loading&&_canLeave){
            _results = null;
            _currentEmail = null;
            _openedKey = null;
          }
          return new Future(()=>_results==null);
        }
    );
  }
}

bool _removing = false;

enum ListName{
  history,unlocked
}

class ListPage extends StatefulWidget{

  final ListName type;

  ListPage(this.type):super(key:new ObjectKey(type));

  @override
  _ListPageState createState() => new _ListPageState();
}

String _currentSearch = "";
List<dynamic> _list;
bool _searching = false;

class _ListPageState extends State<ListPage>{

  final SlidableController _slidableController = new SlidableController();

  String _listName;

  @override
  void initState(){
    super.initState();
    _listName = widget.type==ListName.history?"history":"unlocked";
    _list = new List.from(_userData[_listName]);
  }

  Timer _t;

  TextEditingController _c = new TextEditingController();

  int _opening;

  void _search(String s){
    if(_searching){
      _list = new List.from(_userData[_listName]);
      setState((){
        _list.removeWhere((d)=>!d.toLowerCase().contains(s.toLowerCase()));
      });
      _currentSearch = s;
    }
  }

  void _remove(int i) async{
    if(_loading||_removing){
      return;
    }
    setState((){
      _removing = true;
    });
    int removeIndex = _list.length-i-1;
    String item = _list[removeIndex];
    int count = 0;
    for(int j = _list.length-1; j>removeIndex-1;j--){
      if(_list[j]==_list[removeIndex]){
        count++;
      }
    }
    int count2 = 0;
    int totalIndex = -1;
    for(int j = _userData["history"].length-1;j>-1;j--){
      if(_userData["history"][j]==_list[removeIndex]&&++count2==count){
        _userData["history"].removeAt(j);
        totalIndex = j;
        break;
      }
    }
    setState((){
      _list.removeAt(removeIndex);
    });
    http.Response r = await http.get(_server+"/changeHistory?user=$_userId&index=$totalIndex&item=$item&length=${_userData["history"].length+1}&key=$_secretKey");
    dynamic res = json.decode(r.body);
    if(res is List){
      _userData["history"] = new List.from(res);
      _list = new List.from(res);
      if(_currentSearch.length>0){
        _search(_currentSearch);
      }
    }
    setState((){
      _removing = false;
    });
  }

  @override
  Widget build(BuildContext context){
    return new Scaffold(
        appBar: new AppBar(
            actions: [
              new Row(
                  children: [
                    new Text(_userData["unlocks"].toString(),style: new TextStyle(fontSize: 20.0)),
                    new Container(width:3.0),
                    new Icon(Icons.credit_card,size:20.0,color: Colors.white)
                  ]
              ),
              new IconButton(
                icon: new Icon(_searching?Icons.close:Icons.search),
                onPressed: (){
                  if(_loading||_removing){
                    return;
                  }
                  setState((){
                    _searching = !_searching;
                    if(!_searching){
                      if(_t!=null){
                        _t.cancel();
                      }
                      _list = new List.from(_userData[_listName]);
                      _c.text = "";
                      _currentSearch = "";
                    }
                  });
                },
              )
            ],
            title: !_searching?new Text(_listName.substring(0,1).toUpperCase()+_listName.substring(1)):new TextField(
              autofocus: true,
              enabled: !(_removing||_loading),
              autocorrect: false,
              controller: _c,
              onChanged: (s){
                if(_t!=null){
                  _t.cancel();
                }
                _t = new Timer(new Duration(milliseconds:500),(){
                  if(_t!=null){
                    _t.cancel();
                  }
                  _search(s);
                });
              },
              onSubmitted: (s){
                _search(s);
              },
              decoration: new InputDecoration(
                  hintText: "Search",
                  border: InputBorder.none
              ),
            ),
            bottom: _loading&&_opening==null?new PreferredSize(child: new Container(height:2,child:new LinearProgressIndicator()), preferredSize: new Size(double.infinity,2.0)):null
        ),
        body: new Container(
            child: new Scrollbar(
                child: new ListView.builder(
                  controller: _s,
                  itemBuilder: (rcontext,i){
                    String email = _list[_list.length-i-1];
                    bool isUnlocked = _userData["unlocked"].contains(email);
                    Widget returned =  new Column(
                        children: [
                          new ListTile(
                              title: new Text(_list[_list.length-i-1]),
                              leading: isUnlocked?new Container(child:new Icon(Icons.lock_open,color:Colors.green),width:40,height:40):new Listener(
                                  child: new InkWell(
                                    child: new ConstrainedBox(
                                      child: new Icon(Icons.lock_outline,color:Colors.red),
                                      constraints: const BoxConstraints(
                                          minHeight: 40.0,
                                          minWidth: 40.0
                                      ),
                                    ),
                                    onTap: () async{
                                      if(_loading||_removing||!_canLeave){
                                        return;
                                      }
                                      if(_userData["unlocks"]==0&&!_isSubbed){
                                        context.findAncestorStateOfType<_AppState>().setState((){
                                          _index = 3;
                                        });
                                        return;
                                      }
                                      showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context)=>new AlertDialog(
                                              title: new Text("Are you sure?"),
                                              content: new Text(_isSubbed?"This is free because you are subscribed":"This will use 1 unlock credit after email verification"),
                                              actions: [
                                                new FlatButton(
                                                    child: new Text("No"),
                                                    onPressed: (){
                                                      Navigator.of(context).pop();
                                                    }
                                                ),
                                                new FlatButton(
                                                    child: new Text("Yes"),
                                                    onPressed: () async{
                                                      _canLeave = false;
                                                      setState((){
                                                        _loading = true;
                                                      });
                                                      Navigator.of(context).pop();
                                                      http.Response response = await http.get(_server+"/startUnlock?email=$email&user=$_userId&key=$_secretKey");
                                                      setState((){
                                                        _loading = false;
                                                      });
                                                      if(response.statusCode==200){
                                                        _userData["unlocking"][response.body] = email;
                                                        Scaffold.of(rcontext).removeCurrentSnackBar();
                                                        Scaffold.of(rcontext).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text("Email sent to $email"),duration: _snackBarDuration));
                                                        await new Future.delayed(new Duration(milliseconds:750));
                                                        if(!_codePageOpened&&!_userData["unlocked"].contains(email)){
                                                          showDialog(
                                                              context: rcontext,
                                                              barrierDismissible: false,
                                                              builder: (context)=>new UnlockDialog()
                                                          );
                                                        }
                                                      }else{
                                                        Scaffold.of(rcontext).removeCurrentSnackBar();
                                                        String errorMessage = response.body=="Blacklisted"?"This email is blacklisted":"Something went wrong";
                                                        Scaffold.of(rcontext).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text(errorMessage),duration: _snackBarDuration));
                                                      }
                                                      _canLeave = true;
                                                    }
                                                )
                                              ]
                                          )
                                      );
                                    },
                                    radius: Material.defaultSplashRadius,
                                    splashColor: Theme.of(context).splashColor,
                                    highlightColor: Theme.of(context).highlightColor,
                                    customBorder: new CircleBorder(),
                                  )
                              ),
                              trailing: _opening==i?new Container(width:24.0,height:24.0,child:new CircularProgressIndicator(strokeWidth: 3.0)):new Icon(Icons.keyboard_arrow_right),
                              onTap: () async{
                                if(_loading||_removing||!_canLeave){
                                  return;
                                }
                                _loading = true;
                                _opening = i;
                                setState((){});
                                http.Response response = await http.get(_server+"/getPasswords?email=$email&user=$_userId&fromHis=true&key=$_secretKey");
                                //print(response.body);
                                if(response.statusCode==200){
                                  _results = json.decode(response.body);
                                  _openedKey = new GlobalKey();
                                  Navigator.push(context,new PageRouteBuilder(
                                      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation){
                                        return new PasswordResults(email);
                                      },
                                      transitionDuration: new Duration(milliseconds: 300),
                                      transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child){
                                        return new FadeTransition(
                                            opacity: animation,
                                            child: child
                                        );
                                      }
                                  )).then((d){
                                    setState((){
                                      _opening = null;
                                    });
                                  });
                                }else{
                                  Scaffold.of(context).removeCurrentSnackBar();
                                  Scaffold.of(context).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, content: new Text("Something went wrong"),duration: _snackBarDuration));
                                }
                                _loading = false;
                                setState((){});
                              }
                          ),
                          i==_list.length-1?new Container():new Divider(height:2)
                        ]
                    );
                    if(widget.type==ListName.history){
                      returned = new Slidable.builder(
                        key: new UniqueKey(),
                        controller: _slidableController,
                        child: returned,
                        actionPane: new SlidableScrollActionPane(),
                        actionExtentRatio: .25,
                        dismissal: new SlidableDismissal(
                            child: new SlidableDrawerDismissal(),
                            dismissThresholds: {SlideActionType.secondary:.5},
                            onDismissed: (s){
                              _remove(i);
                            },
                            onWillDismiss: (s){
                              return new Future<bool>(()=>!_loading&&!_removing);
                            }
                        ),
                        secondaryActionDelegate: SlideActionBuilderDelegate(
                            builder: (context,i,a,s)=>new IconSlideAction(
                                caption: "Remove",
                                color: Colors.red,
                                icon: Icons.delete,
                                onTap: (){
                                  Slidable.of(context).dismiss();
                                }
                            ),
                            actionCount: 1
                        ),
                      );
                    }
                    return returned;
                  },
                  itemCount: _list.length,
                )
            )
        )
    );
  }
}

class StorePage extends StatefulWidget{
  @override
  _StorePageState createState() => new _StorePageState();
}

class _StorePageState extends State<StorePage>{

  @override
  Widget build(BuildContext context){
    return new Scaffold(
        appBar: new AppBar(
            title: new Text("Store"),
            bottom: _loading?new PreferredSize(child: new Container(height:2,child:new LinearProgressIndicator()), preferredSize: new Size(double.infinity,2.0)):null,
            actions: [
              new Row(
                  children: [
                    new Text(_userData["unlocks"].toString(),style: new TextStyle(fontSize: 20.0)),
                    new Container(width:3.0),
                    new Icon(Icons.credit_card,size:20.0,color: Colors.white)
                  ]
              ),
              new IconButton(
                  icon: new Icon(Icons.help_outline),
                  onPressed: (){
                    showDialog(
                        context: context,
                        builder: (context)=>new AlertDialog(
                          title: new Text("Help"),
                          content: new Text("This is the store page. Here you can purchase credits or subscribe to get free unlocks."),
                          actions: [
                            new FlatButton(
                                child: new Text("OK"),
                                onPressed: ()=>Navigator.of(context).pop()
                            )
                          ],
                        )
                    );
                  }
              )
            ]
        ),
        body: new Container(
            child: new Padding(
                padding: EdgeInsets.only(right:15.0,left:15.0),
                child: new ListView(
                    children: [
                      new Column(
                          children: _products.map((p)=>new PurchaseButton(p)).toList()
                      ),
                      new Padding(
                          padding: EdgeInsets.only(bottom:20.0,top:20.0),
                          child: new Card(
                              color: Colors.white30,
                              child: new ListTile(
                                  title: new Text("Blacklist an email",style: new TextStyle(fontSize: 19.0)),
                                  subtitle: new Text("Prevent unlock attempts"),
                                  trailing: new Container(
                                      child: new Row(
                                        children: [
                                          new Text("3",style: new TextStyle(fontSize: 19.0)),
                                          new Container(width:3),
                                          new Icon(Icons.credit_card,size:19.0)
                                        ],
                                        mainAxisAlignment: MainAxisAlignment.end,
                                      ),
                                      width: 40.0
                                  ),
                                  onTap: _available?(){
                                    if(_loading){
                                      return;
                                    }
                                    if(_userData["unlocks"]>=3){
                                      showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context)=>new BlacklistDialog()
                                      );
                                    }else{
                                      Scaffold.of(context).removeCurrentSnackBar();
                                      Scaffold.of(context).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, duration: _snackBarDuration,content: new Text("Not enough credits")));
                                    }
                                  }:null
                              ),
                              margin: EdgeInsets.zero
                          )
                      )
                    ],
                    physics: new ClampingScrollPhysics()
                )
            )
        )
    );
  }
}

class PurchaseButton extends StatefulWidget{

  final ProductDetails _details;

  PurchaseButton(this._details);

  @override
  _PurchaseButtonState createState() => new _PurchaseButtonState();
}

class _PurchaseButtonState extends State<PurchaseButton>{

  String _amount;

  @override
  Widget build(BuildContext rcontext){
    return new Padding(
        padding: EdgeInsets.only(top:20.0),
        child: new Card(
          color: Colors.white30,
          child: new ListTile(
              title: widget._details.id!="unlimited"?new Row(
                  children: [
                    new Text("Purchase $_amount",style: new TextStyle(fontSize: 19.0)),
                    new Container(width:3.0),
                    new Icon(Icons.credit_card,size:16.0,color: _available?Colors.white:Colors.grey)
                  ]
              ):new Text("Subscribe",style: new TextStyle(fontSize:19.0)),
              subtitle: widget._details.id=="unlimited"?new Text("Get free unlocks"):null,
              trailing: new Text("${widget._details.price}"+(widget._details.id=="unlimited"?"/mo":""),style: new TextStyle(fontSize: 19.0)),
              onTap: _available?() async{
                if(_loading){
                  return;
                }
                final PurchaseParam purchaseParam = new PurchaseParam(productDetails:widget._details);
                if(widget._details.id!="unlimited"){
                  context.findAncestorStateOfType<_StorePageState>().setState((){
                    _loading = true;
                  });
                  InAppPurchaseConnection.instance.buyConsumable(purchaseParam:purchaseParam, autoConsume: true);
                }else{
                  if(Platform.isIOS&&!_isSubbed){
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context)=>new AlertDialog(
                            title: new Text("Unlimited Unlocks"),
                            content: new Text("While this subscription is active all unlocks are free of charge."),
                            actions: [
                              new FlatButton(
                                child: new Text("Cancel"),
                                onPressed: (){
                                  Navigator.of(context).pop();
                                },
                              ),
                              new FlatButton(
                                  child: new Text("Purchase"),
                                  onPressed: (){
                                    Navigator.of(context).pop();
                                    rcontext.findAncestorStateOfType<_StorePageState>().setState((){
                                      _loading = true;
                                    });
                                    InAppPurchaseConnection.instance.buyNonConsumable(purchaseParam:purchaseParam);
                                  }
                              )
                            ]
                        )
                    );
                  }else{
                    context.findAncestorStateOfType<_StorePageState>().setState((){
                      _loading = true;
                    });
                    InAppPurchaseConnection.instance.buyNonConsumable(purchaseParam:purchaseParam);
                  }
                }
              }:null
          ),
          margin: EdgeInsets.zero,
        )
    );
  }

  @override
  void initState(){
    super.initState();
    assert(widget._details!=null);
    _amount = widget._details.id=="credit"?"1":widget._details.id=="fivecredits"?"5":"∞";
  }
}

class SettingsPage extends StatefulWidget{
  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>{
  @override
  Widget build(BuildContext context){
    return new Scaffold(
        appBar: new AppBar(title: new Text("Settings"),centerTitle: true),
        body: new Padding(
            padding: EdgeInsets.only(right:15.0,left:15.0,top:15.0),
            child: new ListView(
                physics: new ClampingScrollPhysics(),
                children: [
                  new Row(
                      children: [
                        new Text("Account",style: new TextStyle(fontSize:19)),
                        new InkWell(
                          child: new ConstrainedBox(
                            child: new Icon(Icons.info_outline,color:Colors.white,size: 20.0),
                            constraints: const BoxConstraints(
                                minHeight: 30.0,
                                minWidth: 30.0
                            ),
                          ),
                          onTap: () async{
                            showDialog(
                                context: context,
                                builder: (context)=>new AlertDialog(
                                  title: new Text("Info"),
                                  content: new Text("Your account is associated with a 16 character token. If you buy a new device, you can enter this token to transfer your information."),
                                  actions: [
                                    new FlatButton(
                                      child: new Text("OK"),
                                      onPressed: (){
                                        Navigator.of(context).pop();
                                      },
                                    )
                                  ],
                                )
                            );
                          },
                          radius: Material.defaultSplashRadius,
                          splashColor: Theme.of(context).splashColor,
                          highlightColor: Theme.of(context).highlightColor,
                          customBorder: new CircleBorder(),
                        )
                      ]
                  ),
                  new Container(height:_isSubbed?2.0:0.0),
                  _isSubbed?new Text("You are subscribed so you get free unlocks",style: new TextStyle(color: Colors.grey[400],fontWeight: FontWeight.bold)):new Container(),
                  new Container(height:2.0),
                  new Row(
                      children: [
                        new Text("User token: $_userId",style: new TextStyle(color: Colors.grey[400])),
                        new GestureDetector(
                            child: new Container(
                                width: 30.0,
                                child: new Icon(Icons.content_copy,color:Colors.white,size: 20.0)
                            ),
                            onTap: () async{
                              Scaffold.of(context).removeCurrentSnackBar();
                              Scaffold.of(context).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, duration: _snackBarDuration,content: new Text("Copied to clipboard")));
                              Clipboard.setData(new ClipboardData(text:_userId));
                            }
                        )
                      ]
                  ),
                  new Container(height:2.0),
                  new Text("${_userData["devices"].length} device${_userData["devices"].length!=1?"s":""} using this account (3 max)",style: new TextStyle(color: Colors.grey[400])),
                  new Container(height:10.0),
                  new Card(
                    color: Colors.white30,
                    child: new ListTile(
                        title: new Text("Change account"),
                        trailing: new Icon(Icons.account_circle),
                        onTap: () async{
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context)=>new ChangeIdDialog()
                          );
                        }
                    ),
                    margin: EdgeInsets.zero,
                  ),
                  new Container(height:10.0),
                  new Card(
                    color: Colors.white30,
                    child: new ListTile(
                        title: new Text("Reset this device"),
                        trailing: new Icon(Icons.cancel),
                        onTap: (){
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context)=>new WillPopScope(
                                child: new AlertDialog(
                                    title: new Text("Are you sure?"),
                                    content: new Text("You will lose all unlocked content and recieve a new user token."),
                                    actions: [
                                      new FlatButton(
                                          child: new Text("No"),
                                          onPressed: (){
                                            if(_loading){
                                              return;
                                            }
                                            Navigator.of(context).pop();
                                          }
                                      ),
                                      new FlatButton(
                                          child: new Text("Yes"),
                                          onPressed: () async{
                                            if(_loading){
                                              return;
                                            }
                                            _changingId = true;
                                            _loading = true;
                                            await http.get(_server+"/removeDevice?user=$_userId&device=$_deviceId&key=$_secretKey");
                                            _setUserId(null);
                                            main();
                                            new Timer.periodic(Duration.zero, (t){
                                              if(!_changingId){
                                                t.cancel();
                                                Navigator.of(context).pop();
                                                setState((){});
                                                _loading = false;
                                              }
                                            });
                                          }
                                      )
                                    ]
                                ),
                                onWillPop: ()=>new Future<bool>(()=>!_loading),
                              )
                          );
                        }
                    ),
                    margin: EdgeInsets.zero,
                  ),
                  new Container(height:15),
                  new Text("Get Help",style: new TextStyle(fontSize:19)),
                  new Container(height:10.0),
                  new Card(
                    color: Colors.white30,
                    child: new ListTile(
                        title: new Text("Contact us"),
                        trailing: new Icon(Icons.mail_outline),
                        onTap: () async{
                          var url = Uri.encodeFull("mailto:support@platypuslabs.llc?subject=GetPass&body=Contact Reason: ");
                          if(await canLaunch(url)){
                            await launch(url);
                          }else{
                            Scaffold.of(context).removeCurrentSnackBar();
                            Scaffold.of(context).showSnackBar(new SnackBar(backgroundColor: _snackBarColor, duration: _snackBarDuration,content: new Text("Something went wrong")));
                          }
                        }
                    ),
                    margin: EdgeInsets.zero,
                  ),
                  new Container(height:10),
                  new Padding(
                      padding: EdgeInsets.only(bottom:20.0),
                      child: new Card(
                          color: Colors.white30,
                          child: new ListTile(
                              title: new Text("Restore purchases"),
                              trailing: new Icon(Icons.info_outline),
                              onTap: (){
                                if(_loading){
                                  return;
                                }
                                showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (context)=>new AlertDialog(
                                      title: new Text("Restore Purchases"),
                                      content: new Text("In order to restore past purchases, you must log into the account you used to make these purchases."),
                                      actions: [
                                        new FlatButton(
                                            child: new Text("OK"),
                                            onPressed: ()=>Navigator.of(context).pop()
                                        )
                                      ],
                                    )
                                );
                              }
                          ),
                          margin: EdgeInsets.zero
                      )
                  )
                ]
            )
        )
    );
  }
}

class UnlockPasswordDialog extends StatefulWidget{

  final String _email;

  UnlockPasswordDialog(this._email);

  @override
  _UnlockPasswordDialogState createState()=>new _UnlockPasswordDialogState();
}

class _UnlockPasswordDialogState extends State<UnlockPasswordDialog>{

  FocusNode _f = new FocusNode();
  String _passwordGuess = "";
  String _errorText;
  bool _passLoading = false;

  void _submit() async{
    if(_passLoading){
      return;
    }
    if(_f.hasFocus){
      _f.unfocus();
    }
    setState((){
      _passLoading = true;
    });
    if(_passwordGuess.length>0){
      Map<String,dynamic> unlockRes = json.decode((await http.get(_server+"/unlockPassword?user=$_userId&email=${widget._email}&password=${_passwordGuess.toLowerCase()}&key=$_secretKey")).body);
      if(unlockRes["unlocked"]==true){
        _results["data"][unlockRes["index"]] = unlockRes["password"];
        _passLoading = false;
        context.findAncestorStateOfType<_AppState>().setState((){});
        Navigator.of(context).pop();
        return;
      }else{
        _errorText = "Incorrect guess";
        _passLoading = false;
      }
    }else{
      _errorText = "Invalid password";
      _passLoading = false;
    }
    setState((){});
  }

  @override
  Widget build(BuildContext context){
    return new WillPopScope(
      child: new AlertDialog(
          title: new Text("Enter password guess"),
          content: new TextField(
              decoration: new InputDecoration(
                  border: new OutlineInputBorder(),
                  isDense: true,
                  labelText: "Password",
                  filled: true,
                  enabled: !_passLoading,
                  errorText: _errorText,
                  suffix: _passLoading?new Container(height:16.0,width:16.0,child:new CircularProgressIndicator(strokeWidth: 2.5)):new Container(height:0,width:0)
              ),
              focusNode: _f,
              onSubmitted: (s){
                _submit();
              },
              onChanged: (s){
                _passwordGuess = s;
                if(_errorText!=null){
                  setState((){
                    _errorText = null;
                  });
                }
              },
              autocorrect: false
          ),
          actions: [
            new FlatButton(
                child: new Text("Cancel"),
                onPressed: (){
                  if(_passLoading){
                    return;
                  }
                  Navigator.of(context).pop();
                }
            ),
            new FlatButton(
                child: new Text("Submit"),
                onPressed: (){
                  _submit();
                }
            )
          ]
      ),
      onWillPop: ()=>new Future<bool>(()=>!_passLoading),
    );
  }
}

class ChangeIdDialog extends StatefulWidget{
  @override
  _ChangeIdDialogState createState()=>new _ChangeIdDialogState();
}

class _ChangeIdDialogState extends State<ChangeIdDialog>{

  FocusNode _f = new FocusNode();
  String _newAccount = "";
  String _errorText;

  void _submit() async{
    if(_loading){
      return;
    }
    if(_f.hasFocus){
      _f.unfocus();
    }
    setState((){
      _loading = true;
    });
    if(_newAccount.length==16&&_newAccount!=_userId){
      bool valid = (await http.get(_server+"/checkId?user=$_newAccount&key=$_secretKey")).body=="true";
      if(valid){
        _changingId = true;
        await http.get(_server+"/removeDevice?user=$_userId&device=$_deviceId&key=$_secretKey");
        _setUserId(_newAccount);
        main();
        new Timer.periodic(Duration.zero, (t){
          if(!_changingId){
            t.cancel();
            _loading = false;
            Navigator.of(context).pop();
            context.findAncestorStateOfType<_AppState>().setState((){});
          }
        });
      }else{
        _errorText = "Invalid token";
        _loading = false;
      }
    }else if(_userId==_newAccount){
      _errorText = "Already in use";
      _loading = false;
    }else{
      if(_newAccount.length!=0){
        _errorText = "Invalid length";
      }
      _loading = false;
    }
    setState((){});
  }

  @override
  Widget build(BuildContext context){
    return new WillPopScope(
      child: new AlertDialog(
          title: new Text("Enter user token"),
          content: new TextField(
              decoration: new InputDecoration(
                  border: new OutlineInputBorder(),
                  isDense: true,
                  labelText: "Token",
                  filled: true,
                  enabled: !_loading,
                  errorText: _errorText,
                  suffix: _loading?new Container(height:16.0,width:16.0,child:new CircularProgressIndicator(strokeWidth: 2.5)):new Container(height:0,width:0)
              ),
              maxLength: 16,
              focusNode: _f,
              onSubmitted: (s){
                _submit();
              },
              onChanged: (s){
                _newAccount = s;
                if(_errorText!=null){
                  setState((){
                    _errorText = null;
                  });
                }
              },
              autocorrect: false
          ),
          actions: [
            new FlatButton(
                child: new Text("Cancel"),
                onPressed: (){
                  if(_loading){
                    return;
                  }
                  Navigator.of(context).pop();
                }
            ),
            new FlatButton(
                child: new Text("Submit"),
                onPressed: (){
                  _submit();
                }
            )
          ]
      ),
      onWillPop: ()=>new Future<bool>(()=>!_loading),
    );
  }
}


class BlacklistDialog extends StatefulWidget{
  @override
  _BlacklistDialogState createState()=>new _BlacklistDialogState();
}

class _BlacklistDialogState extends State<BlacklistDialog>{

  FocusNode _f = new FocusNode();
  String _email = "";
  String _errorText;

  void _submit() async{
    if(_loading){
      return;
    }
    if(_f.hasFocus){
      _f.unfocus();
    }
    setState((){
      _loading = true;
    });
    RegExp regex = new RegExp(r".+@[^\.@]+\.[^\.@]+");
    if(regex.stringMatch(_email)==_email&&!_email.contains(" ")&&_userData["unlocked"].contains(_email)){
      http.Response r = await http.get(_server+"/blackList?user=$_userId&email=$_email&key=$_secretKey");
      if(r.statusCode==200){
        _loading = false;
        Navigator.of(context).pop();
        _userData["unlocks"]-=3;
        context.findAncestorStateOfType<_AppState>().setState((){});
      }else{
        if(r.body=="Already blacklisted"){
          _errorText = "Already Blacklisted";
        }else if(r.body=="Not owned"){
          _errorText = "You do not own this email";
        }else{
          _errorText = "Something went wrong";
        }
        setState((){
          _loading = false;
        });
      }
    }else{
      setState((){
        if(_email.length!=0){
          _errorText = regex.stringMatch(_email)!=_email?"Invalid Email":"You do not own this email";
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context){
    return new WillPopScope(
        child: new AlertDialog(
            title: new Text("Enter email"),
            content: new TextField(
                decoration: new InputDecoration(
                    border: new OutlineInputBorder(),
                    isDense: true,
                    labelText: "Email",
                    filled: true,
                    enabled: !_loading,
                    errorText: _errorText,
                    suffix: _loading?new Container(height:16.0,width:16.0,child:new CircularProgressIndicator(strokeWidth: 2.5)):new Container(height:0,width:0)
                ),
                focusNode: _f,
                onSubmitted: (s){
                  _submit();
                },
                onChanged: (s){
                  _email = s;
                  if(_errorText!=null){
                    setState((){
                      _errorText = null;
                    });
                  }
                },
                autocorrect: false,
                inputFormatters: [new EmailTextFormatter()],
                keyboardType: TextInputType.emailAddress
            ),
            actions: [
              new FlatButton(
                  child: new Text("Cancel"),
                  onPressed: (){
                    if(_loading){
                      return;
                    }
                    Navigator.of(context).pop();
                  }
              ),
              new FlatButton(
                  child: new Text("Submit"),
                  onPressed: (){
                    _submit();
                  }
              )
            ]
        ),
        onWillPop: ()=>new Future<bool>(()=>!_loading)
    );
  }
}

class UnlockDialog extends StatefulWidget{
  @override
  _UnlockDialogState createState()=>new _UnlockDialogState();
}

class _UnlockDialogState extends State<UnlockDialog>{

  FocusNode _f = new FocusNode();
  String _input = "";
  String _errorText;

  @override
  void initState(){
    super.initState();
    _codePageOpened = true;
  }

  @override
  void dispose(){
    super.dispose();
    _codePageOpened = false;
  }

  void _submit() async{
    if(_loading){
      return;
    }
    if(_f.hasFocus){
      _f.unfocus();
    }
    setState((){
      _loading = true;
    });
    RegExp regex = new RegExp(r"\d{6}");
    if(regex.stringMatch(_input)==_input){
      String key = _input;
      String email = _userData["unlocking"][key];
      if(email!=null){
        http.Response r = await http.get(_server+"/endUnlock?user=$_userId&unlockKey=$key&key=$_secretKey");
        if(r.statusCode==200){
          _isSubbed = json.decode(r.body);
          _userData["unlocked"].add(email);
          _userData["unlocking"].remove(key);
          if(_index==2&&email.contains(_currentSearch)){
            _list.add(email);
          }
          if(!_isSubbed&&!_isAdmin){
            _userData["unlocks"]--;
          }
          if(_currentEmail==email){
            http.Response r = await http.get(_server+"/getPasswords?email=$email&user=$_userId&fromHis=true&key=$_secretKey");
            if(r.statusCode==200){
              _results = json.decode(r.body);
              _openedKey.currentState.setState((){});
            }
          }
          _loading = false;
          Navigator.of(context).pop();
        }else{
          _errorText = r.body=="No Unlocks Left"?"Out of unlocks":"Something went wrong";
        }
      }else{
        _errorText = "Invalid code";
      }
      _loading = false;
      context.findAncestorStateOfType<_AppState>().setState((){});
    }else{
      setState((){
        if(_input.length!=0){
          _errorText = "Invalid code";
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context){
    return new WillPopScope(
        child: new AlertDialog(
            title: new Text("Enter code"),
            content: new TextField(
                decoration: new InputDecoration(
                    border: new OutlineInputBorder(),
                    isDense: true,
                    labelText: "Code",
                    filled: true,
                    enabled: !_loading,
                    errorText: _errorText,
                    suffix: _loading?new Container(height:16.0,width:16.0,child:new CircularProgressIndicator(strokeWidth: 2.5)):new Container(height:0,width:0)
                ),
                focusNode: _f,
                onSubmitted: (s){
                  _submit();
                },
                onChanged: (s){
                  _input = s;
                  if(_errorText!=null){
                    setState((){
                      _errorText = null;
                    });
                  }
                },
                autocorrect: false,
                inputFormatters: [new NumberTextFormatter()],
                keyboardType: TextInputType.number,
                maxLength:6
            ),
            actions: [
              new FlatButton(
                  child: new Text("Cancel"),
                  onPressed: (){
                    if(_loading){
                      return;
                    }
                    Navigator.of(context).pop();
                  }
              ),
              new FlatButton(
                  child: new Text("Submit"),
                  onPressed: (){
                    _submit();
                  }
              )
            ]
        ),
        onWillPop: ()=>new Future<bool>(()=>!_loading||!_codePageOpened)
    );
  }
}

class NumberTextFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue){
    return new RegExp(r"\d*").stringMatch(newValue.text)==newValue.text?newValue:oldValue;
  }
}

class EmailTextFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue){
    return !newValue.text.contains(" ")?newValue.copyWith(text:newValue.text.toLowerCase()):oldValue;
  }
}