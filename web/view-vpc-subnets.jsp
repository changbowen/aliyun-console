<%@ page contentType="text/html;charset=UTF-8"%>
<html>
<head>
    <title>VPC Connections View</title>

    <!--jquery libraries-->
    <script class="js_jquery" src="js/external/jquery/jquery-3.3.1.min.js"></script>
    <%--<script class="js_jquery" src="js/external/jquery/jquery-3.3.1.js"></script>--%>
    <script class="js_jquery_cookie" src="js/external/jquery/jquery.cookie-1.4.1.min.js"></script>
    <script class="js_jquery_ui" src="js/external/jquery/jquery-ui-1.12.1/jquery-ui.min.js"></script>

    <!--tippy libraries-->
    <script class="js_tippy" src="js/external/tippy.all.min.js"></script>

    <!--d3 libraries-->
    <script class="js_d3" src="js/external/d3js/d3.js"></script>

    <%--datatables libraries--%>
    <link rel="stylesheet" href="js/external/DataTables/datatables.min.css">
    <script src="js/external/DataTables/datatables.min.js"></script>

    <!--custom theme styles-->
    <link class="css_custom css_fonts" rel="stylesheet" href="css/fonts.css">
    <link class="css_custom css_table_view" rel="stylesheet" href="css/table_view.css">
    <link class="css_custom css_theme_control" rel="stylesheet" href="css/theme_control.css">
    <link class="css_custom css_tippy_custom" rel="stylesheet" href="css/tippy_custom.css">

    <!--custom javascripts-->
    <script class="js_custom js_btn_callbacks" src="js/btn_callbacks.js"></script>
    <script class="js_custom js_d3_chord_gen" src="js/d3_chord_gen.js"></script>
    <script class="js_custom js_helpers" src="js/helpers.js"></script>
    <script class="js_custom js_helpers_web" src="js/helpers_web.js"></script>

    <%--ecs panel template--%>
    <link rel="import" id="template_ecs_panel" href="template_ecs_panel.html">
    <link rel="import" id="template_inst_box" href="template_inst_box.html">

    <style>
        td, th {
            border-radius: 5px;
            vertical-align: top;
            border: solid transparent;
        }

        th {
            vertical-align: middle;
        }

        td .cellBanner {
            text-align: center;
            font-size: 9pt;
            color: #4d4d4d;
        }

        table {
            border-spacing: 5px !important;
        }

        .tooltip {
            width: initial;
            color: whitesmoke;
            background-color: gray;
            background-position: 120%, 120%, 99% 0;
            background-repeat: no-repeat;
            background-size: 13%, 13%, 100% auto;
            border: 0;
            border-radius: 5px;
            padding: 6px;
            margin: 5px;
            font-size: 10pt;
            transition: opacity 0.3s, background 0.3s, transform 0.3s, text-shadow 0.3s;
            box-shadow: 0px 2px 5px dimgrey;
            cursor: pointer;
        }

        .tooltip:hover {
            transform: scale(1.1);
            text-shadow: 0 0 4px black;
            background-position: 73%, 96%, 100% 0;
            background-size: 13%, 13%, 400% auto;
        }

        .subnet {
            border-radius: 5px;
            background-color: #0000000f;
            margin: 3px;
            padding: 2px;
        }

        .tippy-tooltip {
            background-color: unset;
        }

        .tippy-popper {
            width: fit-content;
        }
    </style>

    <script>
        $(document).ready(function () {
            //add back button
            addHomeButton();
            //update select from cookies
            loadCookies(['target_region', 'search_cs']);
            //initialize dataTable
            initDataTables('.dataTable', false, false);
        });
    </script>
</head>
<body>
<h3>Select Region</h3>
<form id="options_form" method="post">
    <select id="target_region" name="target_region">
        <option disabled selected value>-- Select Region --</option>
        <option value="cn-beijing">China North 2 (Beijing)</option>
        <option value="cn-hongkong">Hong Kong</option>
    </select>
    <input type="checkbox" name="refresh_cache" id="refresh_cache">Ignore Cache (Slow)
    <input type="checkbox" name="search_cs" id="search_cs">Case Sensitive Search
    <input type="submit" id="btn_submit" value="Go" onclick="btn_submit_onclick()"/>
</form>

<%
    String[] p_target_region = request.getParameterValues("target_region");
    if (p_target_region == null || p_target_region.length == 0) return;
%>

<script>
    'use strict';
    let region = $.cookie('target_region');
    let cache = $.cookie('refresh_cache') !== 'true';//cannot use ! to invert boolean as cookies are stored as strings

    let /**Map*/ allVpc = getInstances(region, 'Vpc', null, cache, null, 'map');
    let /**Map*/ allVsw = getInstances(region, 'Vswitch', null, cache, null, 'map');
    let /**Map*/ allEcs = getInstances(region, 'Ecs', null, cache, null, 'map');
    let /**Map*/ allSG = getInstances(region, 'SecurityGroup', null, cache, null, 'map');
    let /**Array*/ allDisk = getInstances(region, 'Disk', null, cache, null);
    let allEcsDisk = allDisk.reduce((pre, cur) =>
        pre.has(cur.instanceId) ? (pre.get(cur.instanceId).push(cur), pre) : pre.set(cur.instanceId, [cur]), new Map());

    if (allVpc.size + allVsw.size + allEcs.size === 0) throw new Error('Empty collections. Aborting.');

    //generate data for table display
    /** @type { Map<string,Array<{vswList:Array,ecsList:Array}>> }*/
    let rows = [...allVsw.values()].reduce((pre, cur) => pre.has(cur.vSwitchName) ? pre : pre.set(cur.vSwitchName, Array(allVpc.size)), new Map());
    let cols = [...allVpc.values()].reduce((pre, cur, i) => pre.set(cur.vpcId, i), new Map());

    for (let vsw of allVsw.values()) {
        let ary = rows.get(vsw.vSwitchName);
        let vpcIdx = cols.get(vsw.vpcId);
        if (ary[vpcIdx] == null) ary[vpcIdx] = {};
        ary[vpcIdx][vsw.vSwitchId] = { vSwitch: vsw };
        ary[vpcIdx][vsw.vSwitchId].ecsList = [];
    }

    for (let ecs of allEcs.values()) {
        let vsw = allVsw.get(ecs.vpcAttributes.vSwitchId);
        let vpcIdx = cols.get(ecs.vpcAttributes.vpcId);
        rows.get(vsw.vSwitchName)[vpcIdx][vsw.vSwitchId].ecsList.push(ecs);
    }

    /* data structure example of rows:
     - 'net-connesso-A' ─┬─ (empty)                    ┌─ {ecs obj}    //no vSwitch with same name in VPC index 0
                         ├─ (empty)                    ├─ {ecs obj}    //no vSwitch with same name in VPC index 1
                         ├─ {vSwitch: {vsw}, ecsList: ─┴─ {ecs obj}}   //vSwitch with same name in VPC index 2
                         ├─ {vSwitch: {vsw}, ecsList: ─┬─ {ecs obj}}   //vSwitch with same name in VPC index 3
                         ├─ ...                        └─ ...
                         └─ {vSwitch: {vsw}, ecsList: []}              //vSwitch with same name in VPC index n without any ECS inside
    */

    //header row
    let table = d3.select('body').append('table').attr('class', 'dataTable display cell-border');
    let headerRow = table.append('thead').append('tr');
    headerRow.selectAll('th')
        .data([...allVpc.values()], vpc => vpc.vpcId).enter()
        .append('th').text(vpc => vpc.vpcName);//insert vpc columns
    headerRow.insert('th', ':first-child').text('vSwitch');//insert 1st column header

    //body rows
    let tbody = table.append('tbody');
    let bodyRows = tbody.selectAll('tr')
        .data([...rows.entries()], kv => kv[0]).enter()
        .append('tr');

    let instBoxNode = document.querySelector('#template_inst_box').import.querySelector('.inst-box');

    bodyRows.selectAll('td')
        .data(kv => kv[1]).enter()
        .append(cd => {
            let td = document.createElement('td');
            if (cd != null) {
                Object.values(cd).forEach(d => {
                    let vswdiv = document.createElement('div');
                    vswdiv.className = 'subnet';
                    vswdiv.appendChild(createElement('p', {'class': 'cellBanner'}, {'innerText': d.vSwitch.cidrBlock + ' | ' + d.vSwitch.zoneId.toUpperCase()}));
                    if (d.ecsList.length > 0) {
                        d.ecsList.sort(getCompareFunc('instanceName'));
                        for (let ecs of d.ecsList) {
                            let clone = document.importNode(instBoxNode, true);
                            fillEcsBoxData(ecs, clone);
                            vswdiv.appendChild(clone);
                        }
                    }
                    td.appendChild(vswdiv);
                });
            }
            return td;
        });

    bodyRows.insert('th', ':first-child').text(kv => kv[0]);//kv[0] is the vSwitchName
    let panelNode = document.querySelector('#template_ecs_panel').import.querySelector('.ecs-panel');

    //tooltip
    tippy('.tooltip', {
        placement: 'right',
        animateFill: false,
        interactive: true,
        trigger: 'click',
        html: function (instDiv) {
            //generate tooltip content
            switch (instDiv.getAttribute('data-InstCat')) {
                case 'ecs':
                    let ecsId = instDiv.getAttribute('data-InstId');
                    let ecs = allEcs.get(ecsId);
                    //fill in ecs data
                    let clone = document.importNode(ecsPanelNode, true);
                    // let clone = ecsPanelNode.cloneNode(true); appears to be the same effect
                    fillEcsPanelData(ecs, allEcsDisk.get(ecs.instanceId), allSG, clone);
                    updateExpand(clone);
                    applyAccordion(clone);
                    return clone;
                case 'rds':
                    return '';
            }
        },
        popperOptions: {
            modifiers: {
                computeStyle: {
                    gpuAcceleration: false
                }
            }
        },
        onShown(instance) {
            let /**HTMLElement*/ panelElement = $('.ecs-panel', instance.popper)[0];
            let billing_gb = panelElement.querySelector('#billing-gb');
            if (billing_gb.getAttribute('data-PriceUpdated') === 'true') return;

            let ecsId = instance.reference.getAttribute('data-InstId');
            let ecs = allEcs.get(ecsId);

            getPrice(ecs.regionId, 'Ecs', ecs.instanceId, function (price) {
                for (let priceType in price) {
                    if (!price.hasOwnProperty(priceType)) continue;
                    let price_p =
                        createElement('p').
                        createElement('strong', null, {'innerText': priceType + ': '}).
                        createElement('span', null, {'innerText': price[priceType].tradePrice + ' ' + price[priceType].currency});
                    $(price_p).hide();
                    billing_gb.appendChild(price_p);
                    $(price_p).show(500);
                }
                billing_gb.setAttribute('data-PriceUpdated', 'true');
            });
        }
    });

</script>

</body>
</html>
