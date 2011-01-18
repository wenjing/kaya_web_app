// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

jQuery(function($){

  // Text area auto expender
  $.fn.inputlimiter = function(options) {
    var opts = $.extend({}, $.fn.inputlimiter.defaults, options);
    if ( opts.boxAttach && !$('#'+opts.boxId).length )
    {
      $('<div/>').appendTo("body").attr({id: opts.boxId, 'class': opts.boxClass}).css({'position': 'absolute'}).hide();
      // apply bgiframe if available
      if ( $.fn.bgiframe )
        $('#'+opts.boxId).bgiframe();
    }
    $(this).each(function(i){
      //$(this).unbind();
      $(this).keyup(function(e){
        if ( $(this).val().length > opts.limit )
          $(this).val($(this).val().substring(0,opts.limit));
        if ( opts.boxAttach )
        {
          $('#'+opts.boxId).css({
            'width': $(this).outerWidth() - ($('#'+opts.boxId).outerWidth() - $('#'+opts.boxId).width()) + 'px',
            'left': $(this).offset().left + 'px',
            'top': ($(this).offset().top + $(this).outerHeight()) - 1 + 'px',
            'z-index': 2000
          });
        }
        var charsRemaining = opts.limit - $(this).val().length;

        var remText = opts.remTextFilter(opts, charsRemaining);
        var limitText = opts.limitTextFilter(opts);

        if ( opts.limitTextShow )
        {
          $('#'+opts.boxId).html(remText + ' ' + limitText);
          // Check to see if the text is wrapping in the box
          // If it is lets break it between the remaining test and the limit test
          var textWidth = $("<span/>").appendTo("body").attr({id: '19cc9195583bfae1fad88e19d443be7a', 'class': opts.boxClass}).html(remText + ' ' + limitText).innerWidth();
          $("#19cc9195583bfae1fad88e19d443be7a").remove();
          if ( textWidth > $('#'+opts.boxId).innerWidth() ) {
            $('#'+opts.boxId).html(remText + '<br />' + limitText);
          }
          // Show the limiter box
          $('#'+opts.boxId).show();
        }
        else
          $('#'+opts.boxId).html(remText).show();
      });
      $(this).keypress(function(e){
        if ( (!e.keyCode || (e.keyCode > 46 && e.keyCode < 90)) && $(this).val().length >= opts.limit )
          return false;
      });
      $(this).blur(function(){
        if ( opts.boxAttach )
        {
          $('#'+opts.boxId).fadeOut('fast');
        }
        else if ( opts.remTextHideOnBlur )
        {
          var limitText = opts.limitText;
          limitText = limitText.replace(/\%n/g, opts.limit);
          limitText = limitText.replace(/\%s/g, ( opts.limit == 1?'':'s' ));
          $('#'+opts.boxId).html(limitText);
        }
      });
    });
  };

  $.fn.inputlimiter.remtextfilter = function(opts, charsRemaining) {
    var remText = opts.remText;
    if ( charsRemaining == 0 && opts.remFullText != null ) {
      remText = opts.remFullText;
    }
    remText = remText.replace(/\%n/g, charsRemaining);
    remText = remText.replace(/\%s/g, ( opts.zeroPlural ? ( charsRemaining == 1?'':'s' ) : ( charsRemaining <= 1?'':'s' ) ) );
    return remText;
  };

  $.fn.inputlimiter.limittextfilter = function(opts) {
    var limitText = opts.limitText;
    limitText = limitText.replace(/\%n/g, opts.limit);
    limitText = limitText.replace(/\%s/g, ( opts.limit <= 1?'':'s' ));
    return limitText;
  };

  $.fn.inputlimiter.defaults = {
    limit: 255,
    boxAttach: true,
    boxId: 'limit_size_box',
    boxClass: 'limit_size_box',
    remText: '%n character%s left',
    remTextFilter: $.fn.inputlimiter.remtextfilter,
    remTextHideOnBlur: true,
    remFullText: null,
    limitTextShow: false,
    limitText: 'limited to %n character%s.',
    limitTextFilter: $.fn.inputlimiter.limittextfilter,
    zeroPlural: true
  };

  var limit_item = $("textarea.limit_size")
  var limit_size_options = {}
  var limit_size = limit_item.attr("limit_size")
  if (limit_size != undefined)
    limit_size_options = $.extend({limit: parseInt(limit_size)}, limit_size_options)
  limit_item.inputlimiter(limit_size_options);


  // Textare/field character limiter
  $.fn.TextAreaExpander = function(minHeight, maxHeight) {

    var hCheck = !($.browser.msie || $.browser.opera);

    // resize a textarea
    function ResizeTextarea(e) {
      // event or initialize element?
      e = e.target || e;
      // find content length and box width
      var vlen = e.value.length, ewidth = e.offsetWidth;
      if (vlen != e.valLength || ewidth != e.boxWidth) {
        if (hCheck && (vlen < e.valLength || ewidth != e.boxWidth)) e.style.height = "0px";
        var h = Math.max(e.expandMin, Math.min(e.scrollHeight, e.expandMax));
        //e.style.overflow = (e.scrollHeight > h ? "auto" : "hidden");
        e.style.height = h + "px";
        e.valLength = vlen;
        e.boxWidth = ewidth;
      } else if (e.height == undefined || e.height < e.expandMin) {
        e.style.height = e.expandMin;
      }
      return true;
    };

    // initialize
    this.each(function() {
      // is a textarea?
      if (this.nodeName.toLowerCase() != "textarea") return;
      // set height restrictions
      var p = this.className.match(/expand(\d+)\-*(\d+)*/i);
      this.expandMin = minHeight || (p ? parseInt('0'+p[1], 10) : 0);
      this.expandMax = maxHeight || (p ? parseInt('0'+p[2], 10) : 99999);
      // zero vertical padding and add events
      var ResetTextarea = function(){
        if (this.value == "") {
          this.style.height = ""
          this.valLength = undefined;
        }
      };
      if (!this.Initialized) {
        this.Initialized = true;
        $(this).css("padding-top", 0).css("padding-bottom", 0);
        $(this).bind("keydown", ResizeTextarea).bind("focus", ResizeTextarea).bind("blur", ResetTextarea);
      }
      // initial resize
      if ($(this).val() != "") ResizeTextarea(this);
    });

    return this;
  };
  # Also disable resize on all auto expander textarea's
  $("textarea[class*=expand]").TextAreaExpander().css({'resize':'none'});


  // Pass plugin parameters
  $.fn.get_params = function(attr_name) {
    var params = {};
    var attr_values = this.attr(attr_name);
    if (!attr_values)
      return params;
    attr_values = attr_values.split(',');
    for (var ii in attr_values) {
      var attr_item = attr_values[ii].match(/\s*(.+)\s*=>\s*(.+)\s*$/i);
      if (attr_item.length == 3)
        params[attr_item[1]] = attr_item[2];
    }
    return params;
  };


  // Float toggle visible item to best location considering container, window height
  // and current mouse location.
  $.fn.hover_display_toggle = function(center, container_class) {
    this.each(function() {
      var item = $(this);
      if (item.is(":hidden") && container != undefined) {
        var container = item.closest('.'+container);
        var view = $(window);
        var container_top = container.offset().top;
        var container_bottom = container_top + container.height();
        var view_top = view.offset().top;
        var view_bottom = view_top + view.height();
        var target_top = Math.max(container_top, view_top);
        var target_bottom = Math.min(container_bottom, view_bottom);
        target_height = container_bottom - target_top; 
        item.css('max_height',target_height).css('overflow','hidden');
        item.toggle();
        target_height = item.height();
        var target_offset = target_top;
        // Try to pull item center closer to targeted center location
        if (target_height < target_bottom-target_top) {
          target_offset = center - target_height/2;
          if (target_offset < target_top)
            target_offset = target_top;
          else (target_offset + target_height > target_bottom)
            target_offset = target_bottom - target_height;
        }
        item.css('position','fixed').('top', target_offset+'px')
      } else
        item.toggle();
    });
  }

 
  // Hover to display items (use hover_toggle_visibility for visibility manipulation)
  $.fn.hover_display_toggle = function() {
    this.each(function() {
      var params = $(this).get_params('hover_display_toggle');
      var hover_display_item;
      if (params.hover_display_id != undefined)
        hover_display_item = $('.hover_display_visible #' + params.hover_display_id + ', '
                               '.hover_display_hidden #' + params.hover_display_id);
      else
        hover_display_item = $(this).find('.hover_display_visible, .hover_display_hidden');
      $(this).hover(
        function (e) {
          hover_display_item.floating_toggle(e.pageY, params.container_class);
        },
        function (e) {
          hover_display_item.floating_toggle(e.pageY, params.container_class);
        }
      );
    });
    return this;
  };
  $('.hover_display_toggle').hover_display_toggle();
  $('.hover_display_visible').hide();


  // Like toggle, but apply to visibility instead
  $.fn.toggle_visibility = function() {
    this.each(function() {
      if ($(this).css('visibility') == 'hidden')
        $(this).css({'visibility':'visible'});
      else
        $(this).css({'visibility':'hidden'});
    });
    return this;
  }


  // Hover to toggle visibility
  $.fn.hover_visibility_toggle = function() {
    this.each(function() {
      var params = $(this).get_params('hover_visibility_toggle');
      var hover_visibility_item;
      if (params.hover_visibility_id != undefined)
        hover_visibility_item = $('.hover_visibility_visible #' + params.hover_visibility_id + ', '
                                  '.hover_visibility_hidden #' + params.hover_visibility_id);
      else
        hover_visibility_item = $(this).find('.hover_visibility_visible, .hover_visibility_hidden');
      $(this).hover(
        function () { hover_visibility_item.toggle_visibility(); },
        function () { hover_visibility_item.toggle_visibility(); }
      );
    });
    return this;
  };
  $('.hover_visibility_toggle').hover_visibility_toggle();
  $('.hover_visibility_visible').css({'visibility':'hidden'});
  $('.hover_visibility_hidden').css({'visibility':'visible'});


  // Hide, display certain items depending on whether the form is active or not
  $.fn.form_toggle = function() {
    this.each(function() {
      var form_content = $(this).find('.form_toggle_content')
      var form_text_content = $(from_content).find('textarea,input:text,input:password')
      var form_value_content = $(from_content).find('input:file')
      var form_check_content = $(from_content).find('radio,checkbox,select')
      var params = $(this).get_params('form_toggle');
      var form_toggle_item;
      if (params.form_toggle_id != undefined) {
        form_toggle_visible = $('.form_toggle_visible #' + params.form_toggle_id);
        form_toggle_enable = $('.form_toggle_enable #' + params.form_toggle_id);
      } else {
        form_toggle_visible = $(this).find('.form_toggle_visible');
        form_toggle_enable = $(this).find('.form_toggle_enable');
      }
      var permanent_toggle = false;
      var toggle_on = false;
      var force_toggle = function(permanent) {
        if (!toggle_on) {
          permanent_toggle = permanent;
          toggle_on = true;
          form_toogle_visible.each (function() {
            form_toggle_visible.show();
          });
          form_toogle_enable.each (function() {
            form_toggle_enable.removeAttr('disabled');
          });
        } else if (!permanent_toggle) {
          toggle_on = false;
          form_toogle_visible.each (function() {
            form_toggle_visible.hide();
          });
          form_toogle_enable.each (function() {
            form_toggle_enable.attr('disabled', 'disabled');
          });
        }
        return this;
      }
      var check_toggle = function() {
        if (!permanent_toggle) {
          is_empty = true;
          $.merge($.merge([],form_text_content),form_check_content).each (function() {
            if ($(this).val() != "") {
              is_empty = false;
              break;
            }
          });
          if (toggle_on && is_empty)
            force_toggle();
          else if (!toggle_on && !is_empty)
            force_toggle();
        }
        return this;
      }
      $form_content.each(function() {
        form_text_content.each (function() {
          $(this).focus(force_toggle(false)).blur(check_toggle);
        });
        form_value_content.each (function() {
          $(this).change(check_toggle);
        });
        form_check_content.each (function() {
          # Force toggle when value changed, keep it on even when changed back
          # to original value
          $(this).change(force_toogle(true));
        });
      });
      // Bind form reset to remove permanent_toggle and triger force_toggle
      $(this).bind("reset", function() {
       permanent_toggle = false;
       if (toggle_on)
         force_toggle();
      });
    });
    return this;
  };
  $('.form_toggle').form_toggle();


  // Forced clickable
  $.fn.force_clickable = function() {
    this.each(function() {
      var params = $(this).get_params("force_clickable");
      if ($(this).is("a,input,button")) return;
      if (params.url) {
        $(this).click(function(event) {
          function is_clean_between(to, target) {
            while (target[0] != to[0] && target[0] != undefined) {
              if (target.is("a,input,button"))
                return false;
              target = $(target.parent());
            }
            return true
          }
          if (is_clean_between($(this), $(event.target))) {
            event.stopPropagation();
            window.location = params.url;
          }
        });
      }
    });
    return this;
  };
  $('.force_clickable').force_clickable();

 
  // Drop down menu
  $.fn.jsddm = function() {
    var timeout    = 500;
    var closetimer = 0;
    var ddmenuitem = 0;
    function jsddm_open() {
      jsddm_canceltimer();
      jsddm_close();
      # Drop down menu
      ddmenuitem = $(this).find('ul').eq(0).css('visibility', 'visible');
    }
    function jsddm_close() {
      if (ddmenuitem) ddmenuitem.css('visibility', 'hidden');
    }
    function jsddm_timer() {
      closetimer = window.setTimeout(jsddm_close, timeout);
    }
    function jsddm_canceltimer() {
      if (closetimer) {
        window.clearTimeout(closetimer);
        closetimer = null;
      }
    }
    this.each(function() {
      $(this).children('li').bind('mouseover', jsddm_open).bind('mouseout', jsddm_timer);
    });
    document.onclick = jsddm_close;
    return this;
  };
  $('ul.jsddm').jsddm();


  // Wrap by outter html
  $.fn.outter_html = function(s) {
    this.each(function() {
      wrapper_html = $(s);
      wrapper_html.insertBefore($(this).html($(this));
    });
  }


  // Following display item
  $.fn.follow_display = function() {
    this.each(function() {
      var params = $(this).get_params("follow_display");
      var top_offset = params.top_offset;
      var bottom_offset = params.bottom_offset;
      if (top_offset != undefined)
        top_offset = parseInt(top_offset);
      else if (bottom_offset != undefined)
        bottom_offset = parseInt(bottom_offset);
      else
        top_offset = 0;
      // Get a reference to the placeholder. This element will take up visual space
      // when the following item is moved into a fixed position.
      var placeholder = $("<div class=follow_display_placeholder></div>");
      // Get a reference to the message whose position we want to "fix" on window-scroll.
      var item = $(this);
      // Get a reference to the window object; we will use this several time,
      // so cache the jQuery wrapper.
      var view = $(window);
 
      // Bind to the window scroll and resize events. Remember, resizing can also
      // change the scroll of the page.
      view.bind( "scroll resize", function(){
        var placeholder_top = placeholder.offset().top;
        var placeholder_bottom = placehoder_top + view.height();
        var view_top = view.scrollTop();
        var view_bottom = view_top + view.height()
        // Check to see if the view had scroll down past the top of the placeholder
        // AND that the item is not yet fixed.
        var to_be_fixed =
             ((top_offset != undefined && (view_top > placeholder_top+top_offset)) ||
             (bottom_offset != undefined && (view_bottom < placeholder_bottom-bottom_offset)));
        if (!item.is(".follow_display_fixed") && to_be_fixed) {
          // The message needs to be fixed. Before we change its positon, we need to re-
          // adjust the placeholder height to keep the same space as the message.
          // NOTE: All we're doing here is going from auto height to explicit height.
          placeholder.height(placeholder.height());
          // Make the message fixed.
          item.addClass("follow_display_fixed").css('position','fixed');
          if (top_offset != undeinfed)
            item.css('top', top_offset+'px')
          else if (bottom_offset != undeinfed)
            item.css('bottom', bottom_offset+'px')

        // Check to see if the view has scroll back up above the message AND that the message is
        // currently fixed.
        } else if (item.is(".follow_display_fixed") && !to_be_fixed) {
          // Make the placeholder height auto again.
          placeholder.removeAttr("height");
          // Remove the fixed position class on the message. This will pop it back into its
          // static position.
          item.removeClass("follow_display_fixed").css('position','');
          if (top_offset != undeinfed)
            item.css('top', '');
          else if (bottom_offset != undeinfed)
            item.css('bottom', '');
        }
      });
    });
  }
  $('.follow_display').follow_display();

  // Disable disabled a href="## "link
  $('a[href=##]').click(function(){ return false; });
})
