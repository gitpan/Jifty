JSAN.use("DOM.Events");

if ( typeof Jifty == "undefined" ) Jifty = { };

Jifty.Calendar = {
    registerDateWidget: function(id) {
        var input = $(id);
        
        if ( !input ) return false;

        DOM.Events.addListener( input, "click", Jifty.Calendar.toggleCalendar );
        return true;
    },

    toggleCalendar: function(ev) {
        var calId  = "cal_" + ev.target.id;
        var wrapId = calId + "_wrap";
        var wrap   = $(wrapId);
        var input  = ev.target;

        if ( Jifty.Calendar.openCalendar == wrapId ) {
            Jifty.Calendar.hideOpenCalendar();
            return;
        }

        Jifty.Calendar.hideOpenCalendar();
        
        /* We need to delay Jifty's canonicalization until after we've
           selected a value via the calendar */
        input["_onblur"] = input.onblur;
        input.onblur     = null;
        
        if ( wrap ) {
            wrap.style.display = "block";
            Jifty.Calendar.openCalendar = wrapId;
            return;
        }

        wrap = document.createElement("div");
        wrap.setAttribute( "id", wrapId );
        
        wrap.style.position = "absolute";
        wrap.style.left     = Jifty.Utils.findPosX( input );
        wrap.style.top      = Jifty.Utils.findPosY( input ) + input.offsetHeight;
        
        input.parentNode.insertBefore( wrap, input.nextSibling );

        var cal;
        
        if ( /^(\d{4})-(\d{2})-(\d{2})/.test(input.value) ) {
            var bits = input.value.match(/^(\d{4})-(\d{2})-(\d{2})/);
            cal = new YAHOO.widget.Calendar( calId,
                                             wrapId,
                                             bits[2]+"/"+bits[1],
                                             bits[2]+"/"+bits[3]+"/"+bits[1]
                                            );
        }
        else {
            cal = new YAHOO.widget.Calendar( calId, wrapId );
        }
        
        cal["onSelect"] = function() {
            input.value = cal.getSelectedDates()[0].formatDate("Y-m-d");
            Jifty.Calendar.hideOpenCalendar();
        };
        cal.render();
        
        Jifty.Calendar.openCalendar = wrapId;
        /*Jifty.Calendar.preventStutter = wrapId;*/
    },

    openCalendar: "",

    hideOpenCalendar: function() {
        if ( Jifty.Calendar.openCalendar ) {
            $( Jifty.Calendar.openCalendar ).style.display = "none";

            /* Get the input's ID */
            var inputId = Jifty.Calendar.openCalendar;
                inputId = inputId.replace(/^cal_/, '');
                inputId = inputId.replace(/_wrap$/, '');

            var input = $( inputId );

            /* Restore the original onblur */
            input.onblur     = input["_onblur"];
            input["_onblur"] = null;
            
            Jifty.Calendar.openCalendar = "";
        }
    }
};

/*DOM.Events.addListener( window, "click", Jifty.Calendar.hideOpenCalendar );*/

