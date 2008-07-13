var HotKeys = {
	'actions': {},

	'add': function(key, func) {
		this.actions[key] = func;
	},

	'listener': function(e) {
		e = e || window.event;

		// no hotkeys in text fields
		var element = getElement(e);
		if (element) {
			var tag = element.tagName.toLowerCase();
			if (tag == 'input' || tag == 'textarea') {
				return;
			}
		}	

		// get key code
		var code;
		if (e.keyCode) {
			code = e.keyCode;
		} else if (e.which) {
			code = e.which;
		}

		// perform action for hotkey
		if (code) {
			var key = HotKeys.lookup(code);
			var func = HotKeys.actions[key];
			if (func) {
				func();
			}
		}
	},
	
	'lookup': function(code) {
		if (code == 27) {
			return 'esc';
		} else {
			return String.fromCharCode(code).toLowerCase();
		}
	},
	
	'attach': function() {
	  attachListener(document, 'keydown', HotKeys.listener);
	}
};

function getElement(e) {
	e = e || window.event;

	var element;
	if (e.target) {
		element = e.target;
	} else if (e.srcElement) {
		element = e.srcElement;
	}

	if (element.nodeType == 3) {
		element = element.parentNode;
	}
	
	return element;
}

function attachListener(target, eventType, func) {
	// target can be an elem or an id
	if (typeof target == 'string') {
		target = document.getElementById(target);
	}

	// add listener
	if (target.addEventListener) {
		target.addEventListener(eventType, func, false);
	} else if (target.attachEvent) {
		target.attachEvent('on'+eventType, func);
	} else {
		target['on'+eventType] = func;
	}
}

function redirect(uri) {
  return function() { window.location = uri };
}
