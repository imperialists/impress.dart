#import('dart:html');

throttle(fn, delay) {
  int handle = 0;
  return (args) {
    window.clearTimeout(handle);
    handle = window.setTimeout(() => fn(args), delay);
  };
}

main() {
  // throttling function calls
  var throttle = (fn, delay) {
    int timer = 0;
    return () => {
      fn(context, args);
    }
  };

  document.on.change.add((event) {
    var api = event.detail.api;
  });

  document.on.keyUp.add((event) {
    if (event.keyCode === 9 || (event.keyCode >= 32 && event.keyCode <= 34) || (event.keyCode >= 37 && event.keyCode <= 40)) {
      switch (event.keyCode) {
        case 33: // pg up
        case 37: // left
        case 38: // up
          api.prev();
          break;
        case 9:  // tab
        case 32: // space
        case 34: // pg down
        case 39: // right
        case 40: // down
          api.next();
          break;
      }
      event.preventDefault();
    }
  });

  document.on.click.add((event) {
  });

  document.on.click.add((event) {
  });

  document.on.touchStart.add((event) {
  });

  // rescale presentation when window is resized
  window.on.resize.add(throttle((event) {
    // force going to active step again, to trigger rescaling
    api.goto(document.query('.active'), 500);
  }, 250));
}
