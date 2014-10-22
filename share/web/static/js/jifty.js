/* An empty class so we can create things inside it */
var Jifty = Class.create();

/* Actions */
var Action = Class.create();
Action.prototype = {
    // New takes the moniker (a string), and an optional array of form
    // elements to additionally take into consideration
    initialize: function(moniker) {
        this.moniker = moniker;

        // Extra form parameters
        this.extras = $A();
        if (arguments.length > 1) {
            this.extras = arguments[1];
        }

        this.register = $('J:A-' + this.moniker);  // Simple case -- no ordering information
        if (! this.register) {
            // We need to go looking -- this also goes looking through this.extras, from above
            var elements = $A(document.getElementsByTagName('input'));
            for (var i = 0; i < this.extras.length; i++)
                elements.push(this.extras[i]);
            for (var i = 0; i < elements.length; i++) {
                if ((Form.Element.getMoniker(elements[i]) == this.moniker)
                 && (Form.Element.getType(elements[i]) == "registration")) {
                    this.register = elements[i];
                    break;
                }
            }
        }

        if (this.register) {
            this.form = Form.Element.getForm(this.register);
            this.actionClass = this.register.value;
        }
    },

    // Returns an Array of all fields in this Action
    fields: function() {
	if(!this.cached_fields) {
	    var elements = new Array;
	    var possible = Form.getElements(this.form);
	    // Also pull from extra query parameters
	    for (var i = 0; i < this.extras.length; i++)
		possible.push(this.extras[i]);

	    for (var i = 0; i < possible.length; i++) {
		if (Form.Element.getMoniker(possible[i]) == this.moniker)
		    elements.push(possible[i]);
	    }
	    this.cached_fields = elements;
	}
        return this.cached_fields;
    },

    buttons: function() {
	var elements = new Array();
	var possible = Form.getElements(this.form);
	for(var i = 0; i < possible.length; i++) {
	    if(possible[i].nodeName == 'INPUT' && possible[i].getAttribute("type") == 'submit') {
		actions = Form.Element.buttonActions(possible[i]);
		//If the button has no actions explicitly associated
		//with it, it's associated with all the actions in the
		//form
		if(   actions.length == 0
		   || actions.indexOf(this.moniker) >= 0) {
		    elements.push(possible[i]);
		}
	    }
	}
	return elements;
    },

    getField: function(name) {
        var elements = this.fields();
        for (var i = 0; i < elements.length; i++) {
            if (Form.Element.getField(elements[i]) == name)
                return elements[i];
        }
        return null;
    },

    // Serialize and return all fields needed for this action
    serialize: function() {
        var fields = this.fields();
        var serialized = new Array;

        for (var i = 0; i < fields.length; i++) {
            serialized.push(Form.Element.serialize(fields[i]));
        }
        return serialized.join('&');
    },

    // Returns true if there is a file upload form as one of our elements
    hasUpload: function() {
        var fields = this.fields();
        for (var i = 0; i < fields.length; i++) {
            if ((fields[i].getAttribute("type") == "file") && fields[i].value)
                return true;
        }
        return false;
    },

    // Return the action as a data structure suitable to be JSON'd
    data_structure: function() {
        var a = {};
        a['moniker'] = this.moniker;
        a['class']   = this.actionClass;

        a['fields']  = {};
        var fields = this.fields();
        for (var i = 0; i < fields.length; i++) {
            var f = fields[i];

            if ((Form.Element.getType(f) != "registration") && (Form.Element.getValue(f) != null)) {
                if (! a['fields'][Form.Element.getField(f)])
                    a['fields'][Form.Element.getField(f)] = {};
                a['fields'][Form.Element.getField(f)][Form.Element.getType(f)] = Form.Element.getValue(f);
            }
        }

        return a;
    },

    // Validate the action
    validate: function() {
        show_wait_message();
        var id = this.register.id;

        new Ajax.Request(
            '/__jifty/validator.xml',  // Right now, the URL is actually completely irrelevant
            {
                asynchronous: 1,
                method: "get",
                parameters: this.serialize() + "&J:VALIDATE=1",
                onComplete:
                    function (request) {
                        var response  = request.responseXML.documentElement;
                        for (var action = response.firstChild; action != null; action = action.nextSibling) {
                            if ((action.nodeName == 'validationaction') && (action.getAttribute("id") == id)) {
                                for (var field = action.firstChild; field != null; field = field.nextSibling) {
                                    // Possibilities for field.nodeName: it could be #text (whitespace),
                                    // or 'blank' (the field was blank, don't mess with the error div), or 'ok'
                                    // (clear the error and warning div!) or 'error' (fill in the error div, clear 
                                    // the warning div!) or 'warning' (fill in the warning div and clear the error div!)
                                    if (field.nodeName == 'error' || field.nodeName == 'warning') {
                                        var err_div = document.getElementById(field.getAttribute("id"));
                                        if (err_div != null) {
                                            err_div.innerHTML = field.firstChild.data;
                                        }
                                    } else if (field.nodeName == 'ok') {
                                        var err_div = document.getElementById(field.getAttribute("id"));
                                        if (err_div != null) {
                                            err_div.innerHTML = '';
                                        }
                                    }
                                }
                            } else if ((action.nodeName == 'canonicalizeaction') && (action.getAttribute("id") == id)) {
                                for (var field = action.firstChild; field != null; field = field.nextSibling) {
                                    // Possibilities for field.nodeName: it could be 'ignored', 'blank' or 'update'
                                    if (field.nodeName == 'update') {
                                        var field_name = field.getAttribute("name");
                                        for (var form_number = 0 ; form_number < document.forms.length; form_number++) {
                                            if (document.forms[form_number].elements[field_name] == null)
                                                continue;
                                            document.forms[form_number].elements[field_name].value = field.firstChild.data;
                                        }
                                    }
                                }
                            }
                        }
                        return true;
                    }
            }
        ); 
        hide_wait_message();
        return false;
    },

    submit: function() {
        show_wait_message();
        new Ajax.Request(
            '/empty',
            { parameters: this.serialize() }
        );
        hide_wait_message();
    },

    disable_input_fields: function() {
	var disable = function() {
            // Triggers https://bugzilla.mozilla.org/show_bug.cgi?id=236791
            arguments[0].blur();
            arguments[0].disabled = true;
	};
	this.fields().each(disable);
	this.buttons().each(disable);
    }
};



/* Forms */
Object.extend(Form, {
    // Return an Array of Actions that are in this form
    getActions: function (element) {
        var elements = new Array;
        var possible = Form.getElements(element);

        for (var i = 0; i < possible.length; i++) {
            if (Form.Element.getType(possible[i]) == "registration")
                elements.push(new Action(Form.Element.getMoniker(possible[i])));
        }
        
        return elements;
    }
});



/* Fields */
Object.extend(Form.Element, {
    // Get the moniker for this form element
    // Takes an element or an element id
    getMoniker: function (element) {
        element = $(element);    

        if (/^J:A(:F)+-[^-]+-.+$/.test(element.name)) {
            var bits = element.name.match(/^J:A(?::F)+-[^-]+-(.+)$/);
            return bits[1];
        } else if (/^J:A-(\d+-)?.+$/.test(element.name)) {
            var bits = element.name.match(/^J:A-(?:\d+-)?(.+)$/);
            return bits[1];
        } else {
            return null;
        }
    },

    // Get the Action for this form element
    // Takes an element or an element id
    getAction: function (element) {
        element = $(element);    

        var moniker = Form.Element.getMoniker(element);
        return new Action(moniker);
    },

    // Returns the name of the field
    getField: function (element) {
        element = $(element);    

        if (/^J:A(:F)+-[^-]+-.+$/.test(element.name)) {
            var bits = element.name.match(/^J:A(?::F)+-([^-]+)-.+$/);
            return bits[1];
        } else {
            return null;
        }
    },

    // The type of Jifty form element
    getType: function (element) {
        element = $(element);

        if (/^J:A-/.test(element.name)) {
            return "registration";
        } else if (/^J:A:F-/.test(element.name)) {
            return "value";
        } else if (/^J:A:F:F-/.test(element.name)) {
            return "fallback";
        } else if (/^J:A:F:F:F-/.test(element.name)) {
            return "doublefallback";
        } else {
            return null;
        }
    },

    // Validates the action this form element is part of
    validate: function (element) {
        Form.Element.getAction(element).validate();
    },

    // Look up the form that this element is part of -- this is sometimes
    // more complicated than you'd think because the form may not exist
    // anymore, or the element may have been inserted into a new form.
    // Hence, we may need to walk the DOM.
    getForm: function (element) {
        element = $(element);

        if (element.virtualform)
            return element.virtualform;

        if (element.form)
            return element.form;

        for (var elt = element.parentNode; elt != null; elt = elt.parentNode) {
            if (elt.nodeName == 'FORM') {
                element.form = elt;
                return elt;
            } 
       }
        return null;
    },

    buttonArguments: function(element) {
        element = $(element);
        if (!element)
            return $H();

        if (((element.nodeName != 'INPUT') || (element.getAttribute("type") != "submit"))
         && ((element.nodeName != 'A')     || (! element.getAttribute("name"))))
            return $H();

        var extras = $H();

        // Split other arguments out, if we're on a button
        var pairs = element.getAttribute("name").split("|");
        for (var i = 0; i < pairs.length; i++) {
            var bits = pairs[i].split('=',2);
            extras[bits[0]] = bits[1];
        }
        return extras;
    },

    buttonActions: function(element) {
        element = $(element);
	var actions = Form.Element.buttonArguments(element)['J:ACTIONS'];
	if(actions) {
	    return actions.split(",");
	} else {
	    return new Array();
	}
    },  

    buttonFormElements: function(element) {
        element = $(element);

        var extras = $A();
        var args = Form.Element.buttonArguments(element);
        var keys = args.keys();
        for (var i = 0; i < keys.length; i++) {
            var e = document.createElement("input");
            e.setAttribute("type", "hidden");
            e.setAttribute("name", keys[i]);
            e.setAttribute("value", args[keys[i]]);
            e['virtualform'] = Form.Element.getForm(element);
            extras.push(e);
        }
        return extras;
    }

});

// Form elements should AJAX validate if the CSS says so
Behaviour.register({
    'input.ajaxvalidation': function(elt) {
        elt.onblur = function () {
            Form.Element.validate(this);
        } 
    },
    'input.date': function(e) {
        if ( !Element.hasClassName( e, 'has_calendar_link' ) ) {
            createCalendarLink(e);
            Element.addClassName( e, 'has_calendar_link' );
        }
    },
    'input.button_as_link': function(e) {
        if ( !Element.hasClassName( e, 'is_button_as_link' ) ) {
            buttonToLink(e);
            Element.addClassName( e, 'is_button_as_link' );
        }
    }
});



/* Regions */
// Keep track of the fragments on the page
var fragments = $H();

var Region = Class.create();
Region.prototype = {
    initialize: function(name, args, path, parent) {
        this.name = name;
        this.args = $H(args);
        this.path = path;
        this.parent = parent ? fragments[parent] : null;
        if (fragments[name]) {
            // If this fragment already existed, we want to wipe out
            // whatever evil lies we might have said earlier; do this
            // by clearing out everything that looks relevant
            var keys = current_args.keys();
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i];
                var parsed = k.match(/^(.*?)\.(.*)/);
                if ((parsed != null) && (parsed.length == 3) && (parsed[1] == this.name)) {
                    delete current_args[k];
                }
            }
        }

        fragments[name] = this;
    },

    setPath: function(supplied) {
        // Merge in from current_args
        var keys = current_args.keys();
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            if (k == this.name) {
                this.path = current_args[k];
            }
        }

        // Update with supplied
        if (supplied != null) {
            this.path = supplied;
        }
        
        // Propagate back to current args
        current_args[this.name] = this.path;

        // Return new value
        return this.path;
    },

    setArgs: function(supplied) {
        supplied = $H(supplied);
        // Merge in current args
        var keys = current_args.keys();
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            var parsed = k.match(/^(.*?)\.(.*)/);
            if ((parsed != null) && (parsed.length == 3) && (parsed[1] == this.name)) {
                this.args[parsed[2]] = current_args[k];
            }
        }

        // Merge in any supplied parameters
        this.args = this.args.merge(supplied);

        // Fill supplied parameters into current args
        keys = supplied.keys();
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            current_args[this.name+'.'+k] = supplied[k];
        }
        
        // Return new values
        return this.args;
    },

    data_structure: function(path, args) {
        // Set the path and args, if given
        if (path)
            this.setPath(path);
        if (args)
            this.setArgs(args);

        // If we have a parent, find our not-qualified name
        var shortname = this.name;
        if (this.parent) {
            shortname = this.name.substr(this.parent.name.length + 1);
        }

        // Return a nummy data structure
        return {
            name: shortname,
            path: this.path,
            args: this.args,
            parent: this.parent ? this.parent.data_structure(null,null) : null
        }
    }
};


// Keep track of the state variables.
var current_args = $H();

// Update a region.  Takes a hash of named parameters, including:
//  - 'actions' is an array of monikers to submit
//  - 'fragments' is an array of hashes, which may have:
//     - 'region' is the name of the region to update
//     - 'args' is a hash of arguments to override
//     - 'path' is the path of the fragment (if this is a new fragment)
//     - 'element' is the CSS selector of the element to update, if 'region' isn't supplied
//     - 'mode' is one of 'Replace', or the name of a Prototype Insertion
//     - 'effect' is the name of a Prototype Effect
function update() {
    show_wait_message();
    var named_args = arguments[0];
    var trigger    = arguments[1];

    // The YAML/JSON data structure that will be sent
    var request = $H();

    // Set request base path
    request['path'] = '/__jifty/webservices/xml';

    // Grab extra arguments (from a button)
    var button_args = Form.Element.buttonFormElements(trigger);

    // Build actions structure
    request['actions'] = {};
    for (var i = 0; i < named_args['actions'].length; i++) {
        var moniker = named_args['actions'][i];
        var a = new Action(moniker, button_args);
        if (a.register) {
            if (a.hasUpload())
                return true;
            a.disable_input_fields();
            request['actions'][moniker] = a.data_structure();
        }
    }

    request['fragments'] = {};
    // Build fragments structure
    for (var i = 0; i < named_args['fragments'].length; i++) {
        var f = named_args['fragments'][i];

        var name = f['region'];

        // Find where we are going to go
        var element = $('region-' + f['region']);
        if (f['element']) {
            var possible = cssQuery(f['element']);
            if (possible.length == 0)
                element = null;
            else
                element = possible[0];
        }
        f['element'] = element;

        // If we can't find out where we're going, bail
        if (element == null)
            continue;

        // If we're removing the element, do it now
        // XXX TODO: Effects on this?
        if (f['mode'] == "Delete") {
            fragments[name] = null;
            Element.remove(element);
            continue;
        }

        f['is_new'] = (fragments[name] ? false : true);
        // If it's new, we need to create it so we can dump it
        if (f['is_new']) {
            // Find what region we're inside
            f['parent'] = null;
            if (f['mode'] && ((f['mode'] == "Before") || (f['mode'] == "After")))
                element = element.parentNode;
            while ((element != null) && (element.getAttribute) && (f['parent'] == null)) {
                if (/^region-/.test(element.getAttribute("id")))
                    f['parent'] = element.getAttribute("id").replace(/^region-/,"");
                element = element.parentNode;
            }

            if (f['parent']) {
                f['region'] = name = f['parent'] + '-' + name;
            }

            // Make the region (for now)
            new Region(name, f['args'], f['path'], f['parent']);
        } else if ((f['path'] != null) && f['toggle'] && (f['path'] == fragments[name].path)) {
            // If they set the 'toggle' flag, and clicking wouldn't change the path
            Element.update(element, '');
            fragments[name].path = null;
            continue;
        } else if (f['path'] == null) {
            // If they didn't know tha path, fill it in now
            f['path'] == fragments[name].path;
        }

        // Update with all new values
        var fragment_request = fragments[name].data_structure(f['path'], f['args']);

        if (f['is_new'])
            // Ask for the wrapper if we are making a new region
            fragment_request['wrapper'] = 1;

        // Push it onto the request stack
        request['fragments'][name] = fragment_request;
    }

    // And when we get the result back..
    var onComplete = function(transport, object) {
        // In case there's no XML in the response, or what have you
        try {
            // Grab the XML response
            var response = transport.responseXML.documentElement;

            // For each fragment we requested
            for (var i = 0; i < named_args['fragments'].length; i++) {
                var f = named_args['fragments'][i];
                var element = f['element'];

                // Change insertion mode if need be
                var insertion = null;
                if (f['mode'] && (f['mode'] != 'Replace')) {
                    insertion = eval('Insertion.'+f['mode']);
                }

                // Loop through the result looking for it
                for (var response_fragment = response.firstChild;
                     response_fragment != null;
                     response_fragment = response_fragment.nextSibling) {
                    if (response_fragment.nodeName == 'fragment') {
                        if (response_fragment.getAttribute("id") == f['region']) {
                            var textContent;
                            if (response_fragment.textContent) {
                                textContent = response_fragment.textContent;
                            } else {
                                textContent = response_fragment.firstChild.nodeValue;
                            }
                            // Once we find it, do the insertion
                            if (insertion) {
                                new insertion(element, textContent.stripScripts());
                            } else {
                                Element.update(element, textContent.stripScripts());
                            }
                            // We need to give the browser some "settle" time before we eval scripts in the body
                            setTimeout((function() { this.evalScripts() }).bind(textContent), 10);
			    Behaviour.apply(f['element']);
                        }
                    }
                }

                // Also, set us up the effect
                if (f['effect']) {
                    var effect = eval('Effect.'+f['effect']);
                    var effect_args  = f['effect_args'] || {};
                    if (f['is_new'])
                        Element.hide($('region-'+f['region']));
                    (effect)($('region-'+f['region']), effect_args);
                }
            }
            for (var result = response.firstChild;
                 result != null;
                 result = result.nextSibling) {
                if (result.nodeName == 'result') {
                    for (var key = result.firstChild;
			 key != null;
			 key = key.nextSibling) {
			show_action_result(result.getAttribute("moniker"),key);
                    }
                }
            }
        } finally {
            // Make the wait message go away
            hide_wait_message();
        }
    };

    // Build variable structure
    request['variables'] = {};
    var keys = current_args.keys();
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        request['variables']['region-'+k] = current_args[k];
    }

    // Push any state variables which we set into the forms
    for (var i = 0; i < document.forms.length; i++) {
        var form = document.forms[i];
        var keys = current_args.keys();
        for (var j = 0; j < keys.length; j++) {
            var n = keys[j];
            if (form['J:V-region-'+n]) {
                form['J:V-region-'+n].value = current_args[n];
            } else {
                var hidden = document.createElement('input');
                hidden.setAttribute('type',  'hidden');
                hidden.setAttribute('name',  'J:V-region-'+n);
                hidden.setAttribute('id',    'J:V-region-'+n);
                hidden.setAttribute('value', current_args[n]);
                form.appendChild(hidden);
            }
        }
    }

    // Set up our options
    var options = { postBody: JSON.stringify(request),
                    onComplete: onComplete,
                    requestHeaders: ['Content-Type', 'text/x-json']
    };

    // Go!
    new Ajax.Request(document.URL,
                     options
                    );
    return false;
}

function trace( msg ){
  if( typeof( jsTrace ) != 'undefined' ){
    jsTrace.send( msg );
  }
}


function show_wait_message (){
    if ($('jifty-wait-message'))
        new Effect.Appear('jifty-wait-message', {duration: 0.5});
}

function hide_wait_message (){
    if ($('jifty-wait-message'))
        new Effect.Fade('jifty-wait-message', {duration: 0.2});
}

function show_action_result() {
    var popup = $('jifty-result-popup');
    if(!popup) return;

    var moniker = arguments[0];
    var result = arguments[1];
    var status = result.nodeName;
    var text = result.textContent;
    if(status != 'message' && status != 'error') return;

    var node = document.createElement('div');
    var node_id = 'result-' + moniker;
    node.setAttribute('id', node_id);
    node.setAttribute('class', 'result-' + status);
    node.innerHTML = text;

    if(popup.hasChildNodes()) {
        popup.insertBefore(node, popup.firstChild);
    } else {
        popup.appendChild(node);
    }
    
    setTimeout(function () {
	    new Effect.Fade(node, {duration: 5.0});
    }, 2000);
}

Jifty.Autocompleter = Class.create();
Object.extend(Object.extend(Jifty.Autocompleter.prototype, Ajax.Autocompleter.prototype), {
  initialize: function(field, div) {
    this.field  = $(field);
    this.action = Form.Element.getAction(this.field);
    this.url    = '/__jifty/autocomplete.xml';


    this.baseInitialize(this.field, $(div));
  },

  getUpdatedChoices: function() {
      var request = { path: this.url, actions: {} };

      var a = {};
      a['moniker'] = 'autocomplete';
      a['class']   = 'Jifty::Action::Autocomplete';
      a['fields']  = {};
      a['fields']['moniker']  = this.action.moniker;
      a['fields']['argument'] = Form.Element.getField(this.field);
      request['actions']['autocomplete'] = a;
      request['actions'][this.action.moniker] = this.action.data_structure();
      request['actions'][this.action.moniker]['active']  = 0;

      var options = { postBody: JSON.stringify(request),
                      onComplete: this.onComplete.bind(this),
                      requestHeaders: ['Content-Type', 'text/x-json']
      };

      new Ajax.Request(this.url,
                       options
                       );
  }


});


// Define hasOwnProperty for Safari
if( !Object.prototype.hasOwnProperty ) {
    Object.prototype.hasOwnProperty = function( property ) {
        try {
            var prototype = this.constructor.prototype;
            while( prototype ) {
                if( prototype[ property ] == this[ property ] ) {
                    return false;
                }
                prototype = prototype.prototype;
            }
        } catch( e ) {}
        return true;
    }
}
