#import('dart:html');
#import('dart:json');

class Vector {
  num x = 0, y = 0, z = 0;
}

class State {
  Vector rot;
  Vector pos;
  num scale;
  num targetScale;
  num perspective;
  bool zoomin;

  State(attributes, winScale, perspective) :
      rot = new Vector(),
      pos = new Vector() {
    num getAttribute(String a, [num def = 0]) =>
      (attributes[a] == null) ?
        def : Math.parseDouble(attributes[a]);

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
    this.perspective = perspective / targetScale;
    this.zoomin = targetScale >= scale;
  }

  String toCSS() =>
      "translate3d(${pos.x}px, ${pos.y}px, ${pos.z}px) rotateX(${rot.x}deg) rotateY(${rot.y}deg) rotateZ(${rot.z}deg) scale(${scale})";

  String canvasCSS() =>
      "position: absolute; -webkit-transform-origin: 0% 0%; -webkit-transition: all 500ms ease-in-out 0ms; -webkit-transform-style: preserve-3d; -webkit-transform: rotateZ(${-rot.z}deg) rotateY(${-rot.y}deg) rotateX(${-rot.x}deg) translate3d(${-pos.x}px, ${-pos.y}px, ${-pos.z}px);";

  String scaleCSS() {
      var t="position: absolute; -webkit-transform-origin: 0% 0%; -webkit-transition: all 500ms ease-in-out 250ms; -webkit-transform-style: preserve-3d; top: 50%; left: 50%; -webkit-transform: perspective(${perspective}) scale(${targetScale});";
      return t;
  }
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
          def : Math.parseDouble(root.dataset[a]);

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
    mImpress.innerHTML = '<div id="canvas">'+ mImpress.innerHTML +'</div>';
    mCanvas = document.query('#canvas');
    mSteps = mCanvas.queryAll('.step');
    mCurrentStep = 0;
    mCfg = new Config(mImpress);
  }

  num winScale()
  {
    num hScale = document.window.innerHeight / mCfg.height;
    num wScale = document.window.innerWidth / mCfg.width;
    num scale = Math.min(hScale,wScale);
    scale = Math.min(mCfg.maxScale,scale);
    scale = Math.max(mCfg.minScale,scale);
    return scale;
  }

  String bodyCSS() =>
    "height: 100%; overflow-x: hidden; overflow-y: hidden;";

  String stepCSS(String s) =>
    "position: absolute; -webkit-transform: translate(-50%, -50%) ${s}; -webkit-transform-style: preserve-3d;";

  void setupPresentation() {
    // Body and html
    document.body.style.cssText = bodyCSS();

    document.head.innerHTML = document.head.innerHTML + '<meta content="width=device-width, minimum-scale=1, maximum-scale=1, user-scalable=no" name="viewport">';

    // Create steps
    mSteps.forEach((Element step) =>
      step.style.cssText = stepCSS(getState(step).toCSS())
    );

    // Create Canvas
    mCanvas.style.cssText = getState(mSteps[0]).canvasCSS();
    mCanvas.elements.first.remove();

    // Scale and perspective
    mImpress.style.cssText = getState(mSteps[0]).scaleCSS();
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
    _socket.on.message.add((e) {
      Map msg = JSON.parse(e.data);

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
    new State(step.attributes, winScale(), mCfg.perspective);

  void goto(int step) {
    // Iterate over attributes of the step jumped to and apply CSS
    mCurrentStep = step;
    mCanvas.style.cssText = getState(mSteps[mCurrentStep]).canvasCSS();
    // Scale and perspective
    mImpress.style.cssText = getState(mSteps[mCurrentStep]).scaleCSS();
  }

  void prev() {
    int prev_ = mCurrentStep - 1;
    goto(prev_ >= 0 ? prev_ : mSteps.length-1);
  }

  void next() {
    int next_ = mCurrentStep + 1;
    goto(next_ < mSteps.length ? next_ : 0);
  }
}

void main() {

  Impress pres = new Impress();
  pres.setupPresentation();

  bool serverControl = false;

  if (serverControl) {

    pres.connectServer();

  } else {

    // trigger impress action (next or prev) on keyup
    document.on.keyUp.add((event) {
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


  /* not used atm

  // delegated handler for clicking on the links to presentation steps
  document.on.click.add((event) {
    // event delegation with "bubbling"
    // check if event taget (or any of its parents is a link)
    var target = event.target;
    while ((target.tagName !== "A") &&
           (target !== document.documentElement)) {
      target = target.parentNode;
    }

    if (target.tagName === "A") {
      var href = target.getAttribute("href");

      // if it's a link to presentation step, target this step
      if (href && href[0] === "#") {
        target = document.query(href.slice(1));
      }
    }

    if (pres.goto(target) != null) {
      event.stopImmediatePropagation();
      event.preventDefault();
    }
  });

  // delegated handler for clicking on step elements
  document.on.click.add((event) {
    var target = event.target;
    // find closest step element that is not active
    while (!(target.classes.contains("step") && !target.classes.contains("active") &&
            (target !== document.documentElement))) {
      target = target.parentNode;
    }
    if (pres.goto(target) != null) {
      event.preventDefault();
    }
  });

  // touch handler to detect taps on the left and right side of the screen
  document.on.touchStart.add((event) {
    if (event.touches.length === 1) {
      var x = event.touches[0].clientX;
      var width = window.innerWidth * 0.3;
      var result = null;

      if (x < width) {
        result = pres.prev();
      } else if (x > window.innerWidth - width) {
        result = pres.next();
      }

      if (result) {
        event.preventDefault();
      }
    }
  });
*/
  // rescale presentation when window is resized
  window.on.resize.add(throttle((event) {
    // force going to active step again, to trigger rescaling
    pres.goto(pres.mCurrentStep);
  }, 250));

}

/**
 * Throttling function calls
 */
throttle(fn, int delay) {
  int handle = 0;
  return (args) {
    window.clearTimeout(handle);
    handle = window.setTimeout(() => fn(args), delay);
  };
}

