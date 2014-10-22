JSAN.use("DOM.Events");

if (typeof Jifty == "undefined") Jifty = { };

Jifty.ContextMenu = {
    behaviourRules: {
        "ul.menu li.toplevel span.expand a": function(e) { e.innerHTML = ""; },
        "ul.context_menu li.toplevel span.expand a": function(e) { e.innerHTML = ""; }
    },

    currently_open:  "",
    prevent_stutter: "",

    getParentListItem: function(ul) {
        /* XXX TODO: Put this in the onclick handler? */
        return ul.parentNode;
    },

    hideshow: function(id) {
        var ul = document.getElementById(id);

        Jifty.ContextMenu.prevent_stutter = id;

        if ( ul.style.display == "block" )
            Jifty.ContextMenu.hide(id);
        else
            Jifty.ContextMenu.show(id);
    },

    hide: function(id) {
        var ul = document.getElementById(id);

        var li = Jifty.ContextMenu.getParentListItem(ul);
        Element.removeClassName(li, "open");
        Element.addClassName(li, "closed");
                             
        ul.style.display = "none";
        Jifty.ContextMenu.currently_open = "";
    },

    show: function(id) {
        var ul = document.getElementById(id);
        
        if (   Jifty.ContextMenu.currently_open
            && Jifty.ContextMenu.currently_open != ul.id )
        {
            Jifty.ContextMenu.hide(Jifty.ContextMenu.currently_open);
        }
    
        var li = Jifty.ContextMenu.getParentListItem(ul);

        if ( ul.style.position == "" ) {
            var x = Jifty.Utils.findPosX( li );
            var y = Jifty.Utils.findPosY( li ) + li.offsetHeight;

            ul.style.position = "absolute";
            ul.style.left     = x + "px";
            ul.style.top      = y + "px";
            ul.style.width    = li.offsetWidth * 2 + "px";
        }

        Element.removeClassName(li, "closed");
        Element.addClassName(li, "open");
         
        ul.style.display = "block";
        Jifty.ContextMenu.currently_open = ul.id;
    },

    hideOpenMenu: function(event) {
        /* This is a bloody hack to deal with the Document based listener
           firing just before our listener on the link.
           If both fire, the window closes and then opens again.
         */
        if (   Jifty.ContextMenu.prevent_stutter
            && Jifty.ContextMenu.prevent_stutter == Jifty.ContextMenu.currently_open)
        {
            Jifty.ContextMenu.prevent_stutter = "";
            return;
        }
        else {
            Jifty.ContextMenu.prevent_stutter = "";
        }
        
        if (Jifty.ContextMenu.currently_open) {
            Jifty.ContextMenu.hide(Jifty.ContextMenu.currently_open);
        }
    }
};

DOM.Events.addListener( window, "click", Jifty.ContextMenu.hideOpenMenu );
Behaviour.register( Jifty.ContextMenu.behaviourRules );

