import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:async';

import 'package:lhs_connections/utils/app_state.dart';
import 'package:lhs_connections/models/User.dart';
import 'package:lhs_connections/utils/grade_level.dart';
import 'package:lhs_connections/utils/loginStatus.dart';


///The AppStateContainer holds the AppState of the currently running app. This
///   includes the currentUser, UserInformation, the status of the login, and
///   a bool saying whether or not the app is loading.
class AppStateContainer extends StatefulWidget {
  final AppState state; ///the state of the currently running app
  final Widget child; ///child of the AppStateContainer; the AppRoot

  ///The constructor for AppStateContainer
  ///   Required Params: Widget child
  ///   Optional Params: AppState state
  AppStateContainer({
    @required this.child,
    this.state
  });

  static _AppStateContainerState of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(_InheritedStateContainer)
        as _InheritedStateContainer)
        .data;
  }

  ///createState() is an inherited method from StatefulWidget which initiates
  ///   the state of the AppStateContainer
  @override
  _AppStateContainerState createState() => new _AppStateContainerState();
}

///The state of the AppStateContainer, this holds the methods that can change
///   the state of the app.
class _AppStateContainerState extends State<AppStateContainer> {
  AppState state; ///the state of the currently running app

  FirebaseUser currUser; ///the current user

  ///the authentication firebase reference
  FirebaseAuth _auth = FirebaseAuth.instance;

  ///reference to the firestore database that holds user information
  CollectionReference dbUsers = Firestore.instance.collection('students');

  @override
  void initState() {

    ///This methods checks to see if a new school year has started and therefore
    ///   needs to update what number is associated with each grade level.
    DateUtil.checkHeaderUpdate();

    ///If the state already exists, then the AppState will be set equal to it.
    ///   Otherwise, the state will be set equal to the initial state and the
    ///   user will be initialized.
    if(widget.state != null) {
      state = widget.state;
    } else {

      state = AppState.initalState();
      initUser();
    }

    super.initState();
  }

  ///initUser() is an asynchronous method that will login the user if they have
  ///   logged it before
  Future<Null> initUser() async {
    await _auth.signOut();
    currUser = await _ensureLoggedInOnStartUp();
    if (currUser == null) {
      setState(() {
        state.isLoading = false;
      });
    } else {

    }
  }

  void startLoading() {
    assert(state.isLoading == false);

    setState(() {
      state.isLoading = true;
    });
  }

  void stopLoading() {
    assert(state.isLoading == true);

    setState(() {
      state.isLoading = false;
    });
  }

  Future<FirebaseUser> _ensureLoggedInOnStartUp() async {
    currUser = await _auth.currentUser();

    if(currUser == null) {
      setState(() {
        state.isLoading = false;
      });
    }

    return currUser;
  }

  ///logIntoFirebase() is an asynchronous method that is called after the user
  ///   hits the login button on the Login page. The app will attempt to find
  ///   the user in the firebase authentication system and import the user's
  ///   information into the app from the firestore.
  ///
  ///   Required Params: String email - the email the user is signing in with
  ///                    String password - the password the user is signing in
  ///                                      with
  ///                    BuildContext context - the context of the login page
  Future<Null> logIntoFirebase(BuildContext context, String email, String password) async {

    ///sets the state of the app to be loading
    setState(() {
      state.isLoading = true;
    });

    print("Starting login");

    try {

      print("Starting login");

      ///Attempts to sign the user in with the given email and password, this
      ///   might throw a USER_NOT_FOUND error or WRONG_PASSWORD error
      
      await _auth.signInWithEmailAndPassword
        (email: email, password: password)
          .then((FirebaseUser user) {
            currUser = user;
          })
          .catchError((e) {
            if (e.toString().contains("ERROR_USER_NOT_FOUND")) {
              setState(() {
                state.isLoading = false;
                state.loginStatus = LoginStatus.UserNotFound;
              });
            } else if (e.toString().contains("ERROR_WRONG_PASSWORD")) {
              setState(() {
                state.isLoading = false;
                state.loginStatus = LoginStatus.PasswordIncorrect;
              });
            }
      });
      ///creates a user object with the user's information inside the app
      User userInformation = await _createUserInformation(email);

      _auth.onAuthStateChanged.listen((FirebaseUser user){
        if(currUser != null) {


          ///sets the user, user information, and a successful login status to the
          ///   app's state. Also tells the app to stop loading.
          setState(() {
            state.isLoading = false;
            state.currentUser = currUser;
            state.userInformation = userInformation;
            state.loginStatus = LoginStatus.Success;
          });

        } else {
          print("Fail");
        }
      });
    } catch (e) {

    }
  }

  /// _createUserInformation() is a private async method that retrieves all of
  ///   the user's information form the firestore and loads it into the app
  Future<User> _createUserInformation(String email) async {
    User userInfo;

    ///gets the documents associated with the id of the firebase user and builds
    ///   a user object out of them.`
    userInfo = await dbUsers.document(email.substring(0, email.indexOf("@"))).get().then((DocumentSnapshot ds) {
      return User.fromSnapshot(ds);
    });

    return userInfo;
  }

  Future<Null> signOutofFirebase() async {

    setState(() {
      state.isLoading = true;
    });

    await _auth.signOut().then((void v) {
      setState(() {
        state.userInformation = null;
        state.isLoading = false;
        state.loginStatus = LoginStatus.NotYetLoggedIn;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedStateContainer(
      data: this,
      child: widget.child,
    );
  }
}

class _InheritedStateContainer extends InheritedWidget {

  final _AppStateContainerState data;

  _InheritedStateContainer({
    Key key,
    @required this.data,
    @required Widget child
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(_InheritedStateContainer old) => true;
}