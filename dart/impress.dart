#import('dart:html');

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

class Vector {
  num x = 0, y = 0, z = 0;
}

class State {
  Vector rot;
  Vector pos;
  num scale = 1;

  State() : rot = new Vector(), pos = new Vector();
}

class Impress {

  // List of all available steps
  ElementList mSteps;
  // Index of the currently active step
  int mCurrentStep;

  Impress() :
    mSteps = document.query('#impress').queryAll('.step'),
    mCurrentStep = 0;

  String stepCSS(String s) =>
    "position: absolute; -webkit-transform: translate(-50%, -50%) ${s}; -webkit-transform-style: preserve-3d;";

  String stateToCSS(State state) =>
      "translate3d(${state.pos.x}px, ${state.pos.y}px, ${state.pos.z}px) rotateX(${state.rot.x}deg) rotateY(${state.rot.y}deg) rotateZ(${state.rot.z}deg) scale(${state.scale})";

  void setupCanvas() {
    mSteps.forEach((Element step) =>
      step.style.cssText = stepCSS(stateToCSS(getState(step)))
    );
  }

  num getAttribute(Element step, String a, num def) =>
    (step.attributes[a] == null) ?
      def : Math.parseDouble(step.attributes[a]);

  State getState(Element step) {
    // We know we want a number, so we can "statically cast"
    num attr(String a, [num def = 0]) => getAttribute(step, a, def);
    State s = new State();
    s.scale = attr('data-scale', 1);
    s.pos.x = attr('data-x');
    s.pos.y = attr('data-y');
    s.pos.z = attr('data-z');
    s.rot.x = attr('data-rotate-x');
    s.rot.y = attr('data-rotate-y');
    s.rot.z = attr('data-rotate-z');
    return s;
  }

  void gotoStep(int step) {
    // Iterate over attributes of the step jumped to and apply CSS
    mSteps[step].attributes.forEach((k,v) {
      ;
    });
    mCurrentStep = step;
  }

  Element goto(target, [duration=0]) {
    return null;
  }

  Element prev() {
    return null;
  }

  Element next() {
    return null;
  }
}

void main() {

  Impress pres = new Impress();
  pres.setupCanvas();

  // prevent default keydown action when one of supported key is pressed
  document.on.keyDown.add((event) {
    if (event.keyCode === 9 || (event.keyCode >= 32 && event.keyCode <= 34 ) || (event.keyCode >= 37 && event.keyCode <= 40)) {
      event.preventDefault();
    }
  });

  // trigger impress action (next or prev) on keyup
  document.on.keyUp.add((event) {
    if (event.keyCode === 9 || (event.keyCode >= 32 && event.keyCode <= 34) || (event.keyCode >= 37 && event.keyCode <= 40)) {
      switch (event.keyCode) {
        case 33: // pg up
        case 37: // left
        case 38: // up
          pres.prev();
          break;
        case 9:  // tab
        case 32: // space
        case 34: // pg down
        case 39: // right
        case 40: // down
          pres.next();
          break;
      }
      event.preventDefault();
    }
  });

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

  // rescale presentation when window is resized
  window.on.resize.add(throttle((event) {
    // force going to active step again, to trigger rescaling
    pres.goto(document.query('.active'), 500);
  }, 250));
}
