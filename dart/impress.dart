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

class Impress {
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
