import 'dart:html';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class Vector {
  num x = 0, y = 0, z = 0;
}

class State {
  Vector rot;
  Vector pos;
  Config cfg;
  num scale;
  num targetScale;
  num rootDelay;
  num canvasDelay;

  State(attributes, winScale, cfg) :
      rot = new Vector(),
      pos = new Vector(),
      cfg = cfg {
    num getAttribute(String a, [num def = 0]) =>
      (attributes[a] == null) ?
        def : double.parse(attributes[a]);

    scale = getAttribute('data-scale', 1);
    pos.x = getAttribute('data-x');
    pos.y = getAttribute('data-y');
    pos.z = getAttribute('data-z');
    rot.x = getAttribute('data-rotate-x');
    rot.y = getAttribute('data-rotate-y');
    // Treat data-rotate as data-rotate-z:
    // Allows using only data-rotate for pure 2D rotation
    rot.z = getAttribute('data-rotate-z', getAttribute('data-rotate'));
    this.targetScale = winScale / scale;
    bool zoomin = targetScale >= scale;
    this.rootDelay = (zoomin ? cfg.transitionDuration/2 : 0);
    this.canvasDelay = (zoomin ? 0 : cfg.transitionDuration/2);
  }

  String get toCSS =>
    "translate3d(${pos.x}px, ${pos.y}px, ${pos.z}px) rotateX(${rot.x}deg) rotateY(${rot.y}deg) rotateZ(${rot.z}deg) scale(${scale})";

  String get canvasCSS =>
    "position: absolute; -webkit-transform-origin: 0% 0%; -webkit-transition: all ${cfg.transitionDuration}ms ease-in-out ${canvasDelay}ms; -webkit-transform-style: preserve-3d; -webkit-transform: rotateZ(${-rot.z}deg) rotateY(${-rot.y}deg) rotateX(${-rot.x}deg) translate3d(${-pos.x}px, ${-pos.y}px, ${-pos.z}px);";

  String get scaleCSS =>
    "position: absolute; -webkit-transform-origin: 0% 0%; -webkit-transition: all ${cfg.transitionDuration}ms ease-in-out ${rootDelay}ms; -webkit-transform-style: preserve-3d; top: 50%; left: 50%; -webkit-transform: perspective(${cfg.perspective / targetScale}) scale(${targetScale});";
}

class Config {
  num height;
  num width;
  num maxScale;
  num minScale;
  num perspective;
  num transitionDuration;

  Config(Element root)
  {
    num getAttribute(String a, num def) =>
        (root.attributes[a] == null) ?
          def : double.parse(root.dataset[a]);

    height = getAttribute("height",768);
    width = getAttribute("width",1024);
    maxScale = getAttribute("maxScale",1);
    minScale = getAttribute("minScale",0);
    perspective = getAttribute("perspective",1000);
    transitionDuration = getAttribute("transitionDuration",1000);
  }
}

class Impress {

  // The top level elements
  Element mImpress;
  Element mCanvas;
  // List of all available steps
  ElementList mSteps;
  // Index of the currently active step
  int mCurrentStep;

  Config mCfg;

  WebSocket _socket;

  Impress()
  {
    mImpress = document.query('#impress');
    mImpress.innerHtml = '<div id="canvas">'+ mImpress.innerHtml +'</div>';
    mCanvas = document.query('#canvas');
    mSteps = mCanvas.queryAll('.step');
    mCurrentStep = 0;
    mCfg = new Config(mImpress);
  }

  num winScale()
  {
    num hScale = window.innerHeight / mCfg.height;
    num wScale = window.innerWidth / mCfg.width;
    num scale = min(hScale,wScale);
    scale = min(mCfg.maxScale,scale);
    scale = max(mCfg.minScale,scale);
    return scale;
  }

  String bodyCSS() =>
    "height: 100%; overflow-x: hidden; overflow-y: hidden;";

  String stepCSS(String s) =>
    "position: absolute; -webkit-transform: translate(-50%, -50%) ${s}; -webkit-transform-style: preserve-3d;";

  void setupPresentation() {
    // Impress is supported
    document.body.classes.remove('impress-not-supported');
    document.body.classes.add('impress-supported');

    // Body and html
    document.body.style.cssText = bodyCSS();

    document.head.innerHtml = document.head.innerHtml + '<meta content="width=device-width, minimum-scale=1, maximum-scale=1, user-scalable=no" name="viewport">';

    // Create steps
    mSteps.forEach((Element step) {
      step.style.cssText = stepCSS(getState(step).toCSS);
      step.classes.add('future');
    });

    // Create Canvas
    mCanvas.style.cssText = getState(mSteps[0]).canvasCSS;
    mCanvas.children.first.remove();

    // Scale and perspective
    mImpress.style.cssText = getState(mSteps[0]).scaleCSS;

    // Go to the first step, unless an explicit step is requested in the href
    goto(window.location.hash.isEmpty ? 0 : int.parse(window.location.hash.substring(1)));
  }

  /**
   * Setup a connection to the presentation server
   * and start listening for commands.
   */
  void connectServer() {
    final Location location = window.location;
    String url = 'ws://${location.host}/ws';
    _socket = new WebSocket(url);

    // Handle command from server
    _socket.onMessage.listen((e) {
      Map msg = JSON.decoder.convert(e.data);

      // Switch slides
      if (msg['state'] is num) {
        goto((msg['state'] - 1) % (mSteps.length));
      }

      // Refresh
      if (msg['refresh']) {
        window.location.reload();
      }
    });
  }

  State getState(Element step) =>
    new State(step.attributes, winScale(), mCfg);

  void goto(int step) {
    // Mark previous steps as passed
    for (int s = mCurrentStep; s < step; s++) {
      mSteps[s].classes.removeAll(['active', 'future']);
      mSteps[s].classes.add('past');
    }
    // Mark current step active
    mSteps[step].classes.removeAll(['past', 'future']);
    mSteps[step].classes.add('active');
    // Mark subsequent steps as future
    for (int s = mCurrentStep; s > step; s--) {
      mSteps[s].classes.removeAll(['past', 'active']);
      mSteps[s].classes.add('future');
    }
    // Iterate over attributes of the step jumped to and apply CSS
    mCurrentStep = step;
    // Due to a dartium bug we can't directly set window.location.hash
    window.location.href = window.location.href.replaceFirst(new RegExp('#[0-9]*'), '') + '#${step}';
    mCanvas.style.cssText = getState(mSteps[mCurrentStep]).canvasCSS;
    // Scale and perspective
    mImpress.style.cssText = getState(mSteps[mCurrentStep]).scaleCSS;
  }

  void prev() {
    goto((mCurrentStep - 1) % mSteps.length);
  }

  void next() {
    goto((mCurrentStep + 1) % mSteps.length);
  }
}

void main() {

  Impress pres = new Impress();

  window.onHashChange.listen((e) {
    int step = int.parse(window.location.hash.substring(1));
    if (step != pres.mCurrentStep)
      pres.goto(step);
  });

  pres.setupPresentation();

  bool serverControl = false;

  if (serverControl) {

    pres.connectServer();

  } else {

    // trigger impress action (next or prev) on keyup
    document.onKeyUp.listen((event) {
      switch (event.keyCode) {
        case 33: // pg up
          pres.prev();
          break;
        case 37: // left
          pres.prev();
          break;
        case 38: // up
          pres.prev();
          break;
        case 9:  // tab
          pres.next();
          break;
        case 32: // space
          pres.next();
          break;
        case 34: // pg down
          pres.next();
          break;
        case 39: // right
          pres.next();
          break;
        case 40: // down
          pres.next();
          break;
      }
      event.preventDefault();
    });

  } // else serverControl

  // rescale presentation when window is resized
  window.onResize.listen((_){
    // force going to active step again, to trigger rescaling
    return new Future.delayed(new Duration(milliseconds: 250)).then((_){
      pres.goto(pres.mCurrentStep);
    });
  });
}

