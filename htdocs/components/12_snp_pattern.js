/*
 * Tested in:
 * FF 3+
 * IE 8
 * Chromium 12
 * Opera 10
*/

$.fn.synchronizeScroll = function () {
    var elements = this;
    if (elements.length <= 1) { return; }

    elements.scroll(function () {
        var left = $(this).scrollLeft();
        var top = $(this).scrollTop();
        elements.each(function () {
            if ($(this).scrollLeft() !== left) { $(this).scrollLeft(left); }
            //if ($(this).scrollTop() !== top) { $(this).scrollTop(top);   }
        });
    });
};


$.fn.setWidth = function (bodyTable) {

    var mainTable  = this;
    var tableWidth = 0;

    // Match table widths
    if (parseInt(mainTable.width(), 10)   > parseInt(bodyTable.width(), 10)) {
        tableWidth = parseInt(mainTable.width(), 10);
    } else {
        tableWidth = parseInt(bodyTable.width(), 10);
    }
  
    //adding some extra length to tableWidth enables the resizing process to go smoothly
    tableWidth = tableWidth + 300;  
    mainTable.width(tableWidth + 'px');
    bodyTable.width(tableWidth + 'px');  

    // Match column widths
    var newWidth = [];
    mainTable.find('tbody tr:last td').each(function (i) { 
        var td = bodyTable.find('tbody tr:last td');
        var newWidth;
        if (!$.browser.msie) {     
            $(td.get(i)).css('width', '100px');
            $(this).css('width',      '100px');
        }
        if (parseInt($(this).width(), 10)	> parseInt($(td.get(i)).width(), 10)) {
            newWidth = parseInt($(this).width(), 10);
        } else {
            newWidth =  parseInt($(td.get(i)).width(), 10);
        }

        $(td.get(i)).css('width', newWidth      + 'px');
        $(this).css('width',      newWidth      + 'px');
    });

};

Ensembl.Panel.SNPPanel = Ensembl.Panel.extend({
    init: function () {
        this.base();
        Ensembl.EventManager.register('CrossScroll', this, this.CrossScroll);
        this.CrossScroll();    
    },

    CrossScroll: function () {

        $(function () {
           
            var tblWidth  = $(window).width();
            var tblHeight = $(window).height();
      
            var tbodyHeight = parseInt(tblHeight, 10) - 320 - parseInt($("div#divHeaderTables", this.el).outerHeight(), 10);
            $("div#divMainH div div table tr td", this.el).css("border",         "solid #66CC99").css("border-width", "1px 0px 0px 1px");
            $("div#divMainH div div table", this.el).css("border",               "solid #66CC99").css("border-width", "0px 0px 1px 0px");

            $("table[id*='ta2'] tr td", this.el).css("border-width",             "1px 1px 0px 1px");
           
            $("table[id*='ta1'] tr td:first-child", this.el).css("border-width", "1px 0px 0px 0px");
            $("table[id*='ta1'] tr td:last-child", this.el).css("border-width",  "1px 1px 0px 1px");

            if(parseInt($("#divBodyTables", this.el).css("height"), 10) > parseInt(tbodyHeight, 10))  {
                $("#divBodyTables", this.el).css("height", parseInt(tbodyHeight, 10));
            }

            $("table#headta1", this.el).setWidth($("table#ta1", this.el));
            $("table#headta3", this.el).setWidth($("table#ta3", this.el));
            $("div.TabBoxV", this.el).synchronizeScroll();
            $("div.TabBoxF", this.el).synchronizeScroll();
            $("div.TabBoxP", this.el).synchronizeScroll();
      

        });
    }

});