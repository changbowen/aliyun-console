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

    <%--import templates--%>
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
            display: block;
            margin: 0.2em 0.3em;
            text-align: center;
            font-size: 9pt;
            color: #4d4d4d;
        }

        table {
            border-spacing: 5px !important;
        }

        .subnet {
            border-radius: 5px;
            background-color: #00000017;
            margin: 3px;
            padding: 2px;
        }

        .tippy-tooltip {
            background-color: unset;
        }

        .tippy-popper {
            width: fit-content;
        }

        .colgrp-odd {
            background-color: #ebf1ff;
        }

        .colgrp-even {
            background-color: #fff2ef;
        }
    </style>

    <script>
        $(document).ready(function () {
            //add back button
            addHomeButton();
            //update select from cookies
            loadCookies(['target_region', 'search_cs']);
            //initialize dataTable
            initDataTables('.dataTable', true);
            //set column group based on first row's rowspan settings
            let /**HTMLElement*/firstRow = $('.dataTable thead tr:nth-child(1)')[0];//vpc row
            let /**HTMLElement*/secondRow = $('.dataTable thead tr:nth-child(2)')[0];//zone row
            if (firstRow == null || secondRow == null) return;
            let lastColClass = false;
            let colClasses = [];
            [...secondRow.children].forEach((cell, cellIdx) => {
                if (cellIdx === 0)
                    colClasses.push(null);
                else {
                    let colHeaderCell = firstRow.children[cellIdx];
                    if (!colHeaderCell.hidden) lastColClass = !lastColClass;
                    colClasses.push(lastColClass);
                }
            });
            colClasses.forEach((b, i) => {
                if (b != null) $('.dataTable tr > :nth-child('+(i+1)+')').addClass(b ? 'colgrp-odd' : 'colgrp-even');
            })
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

    let /**Map*/ allVpc = getInstances(region, 'Vpc', null, cache, null, 'map');//.sort((a, b) => Date.parse(a.creationTime) - Date.parse(b.creationTime))
    let /**Map*/ allVsw = getInstances(region, 'Vswitch', null, cache, null, 'map');
    let /**Map*/ allEcs = getInstances(region, 'Ecs', null, cache, null, 'map');
    let /**Map*/ allSG = getInstances(region, 'SecurityGroup', null, cache, null, 'map');
    let /**Array*/ allDisk = getInstances(region, 'Disk', null, cache, null);
    let /**Map*/ allRds = getInstances(region, 'Rds', null, cache, null, 'map');

    let allEcsDisk = allDisk.reduce((pre, cur) =>
        pre.has(cur.instanceId) ? (pre.get(cur.instanceId).push(cur), pre) : pre.set(cur.instanceId, [cur]), new Map());

    if (allVpc.size + allVsw.size + allEcs.size === 0) throw new Error('Empty collections. Aborting.');

    /**
     * Structure:
     * vpc-xxx ─┬─ cn-beijing-a ─┬─ vsw-xxx: { vSwitch obj }
     *          ├─ cn-beijing-c  ├─ vsw-xxx: { vSwitch obj }
     *          ├─ cn-beijing-e  └─ ...
     *          └─ ...
     */
    let cols = [...allVsw.values()].reduce((pre, cur) => {
        if (pre[cur.vpcId]) {
            if (pre[cur.vpcId][cur.zoneId])
                pre[cur.vpcId][cur.zoneId][cur.vSwitchId] = cur;
            else
                pre[cur.vpcId][cur.zoneId] = { [cur.vSwitchId]: cur };
        }
        else
            pre[cur.vpcId] = { [cur.zoneId]: { [cur.vSwitchId]: cur } };
        return pre;
    }, {});

    /**
     * Structure:
     * {
     *   "vpc-2zefhkx9yqfdgxk3q046d,cn-beijing-a" => [ {vsw obj}, {vsw obj}, ... ],
     *   "vpc-2zefhkx9yqfdgxk3q046d,cn-beijing-c" => [ {vsw obj}, {vsw obj}, ... ],
     *   "vpc-2zejcg6ef7tbekas6f9e5,cn-beijing-a" => [ {vsw obj}, {vsw obj}, ... ],
     *   "vpc-2zejcg6ef7tbekas6f9e5,cn-beijing-e" => [ {vsw obj}, {vsw obj}, ... ],
     *   ...
     * }
     * */
    let colsFlat = Object.entries(cols).reduce((pre, cur) => {
        let vid = cur[0], val = cur[1];
        for (let zid in val) {
            if (!val.hasOwnProperty(zid)) continue;
            pre.set(vid + ',' + zid, { index: pre.size, vpcId: vid, zoneId: zid, vswList: val[zid]});
        }
        return pre;
    }, new Map());

    // let colsData = Object.entries(cols).reduce((pre, cur) => (pre.push(...Object.keys(cur[1]).map(c=>[cur[0], c])), pre), {});

    function getRowKey(vsw) {
        let zoneSuffix = vsw.zoneId.substring(vsw.zoneId.lastIndexOf('-')).toUpperCase();//is something like '-A' or '-C'
        let _i = vsw.vSwitchName.toUpperCase().lastIndexOf(zoneSuffix);
        return _i === -1 ? vsw.vSwitchName : vsw.vSwitchName.substring(0, _i);//remove -A when possible
    }

    /** @type { Map<string,Array> }*/
    let rows = [...allVsw.values()].reduce((pre, cur) => {
        let rowKey = getRowKey(cur);
        let colKey = cur.vpcId + ',' + cur.zoneId;
        let colIdx = colsFlat.get(colKey).index;
        if (!pre.has(rowKey)) pre.set(rowKey, Array(colsFlat.size));
        let row = pre.get(rowKey);
        if (row[colIdx] == null) row[colIdx] = {};
        row[colIdx][cur.vSwitchId] = { vSwitch: cur };
        row[colIdx][cur.vSwitchId].ecsList = [];
        row[colIdx][cur.vSwitchId].rdsList = [];
        return pre;
    }, new Map());

    //fill ecs instances
    for (let ecs of allEcs.values()) {
        let vsw = allVsw.get(ecs.vpcAttributes.vSwitchId);
        let rowKey = getRowKey(vsw);
        let colKey = vsw.vpcId + ',' + vsw.zoneId;
        let colIdx = colsFlat.get(colKey).index;
        rows.get(rowKey)[colIdx][vsw.vSwitchId].ecsList.push(ecs);
    }

    //fill rds instances
    for (let rds of allRds.values()) {
        let vsw = allVsw.get(rds.vSwitchId);
        let rowKey = getRowKey(vsw);
        let colKey = vsw.vpcId + ',' + vsw.zoneId;
        let colIdx = colsFlat.get(colKey).index;
        rows.get(rowKey)[colIdx][vsw.vSwitchId].rdsList.push(rds);
    }

    //header row
    let table = d3.select('body').append('table').attr('class', 'dataTable cell-border hover order-column ');
    let thead = table.append('thead');
    let trh1 = thead.append('tr');
    trh1.selectAll('th').data([...colsFlat.values()]).enter().append('th').text(d => allVpc.get(d.vpcId).vpcName);
    trh1.insert('th', ':first-child');
    let trh2 = thead.append('tr');
    trh2.selectAll('th').data([...colsFlat.values()]).enter().append('th').text(d => d.zoneId);
    trh2.insert('th', ':first-child');

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
                    let vsw = d.vSwitch;
                    let vswdiv = document.createElement('div');
                    vswdiv.className = 'subnet';
                    vswdiv.appendChild(createElement('a', {'class': 'cellBanner'},
                        {
                            'innerText': vsw.cidrBlock + ' | ' + vsw.zoneId.toUpperCase(),
                            'href': 'https://vpcnext.console.aliyun.com/vpc/'+region+'/switches?VSwitchId='+vsw.vSwitchId,
                            'target': '_blank'
                        }));
                    if (d.ecsList.length > 0) {
                        d.ecsList.sort(getCompareFunc('instanceName'));
                        for (let ecs of d.ecsList) {
                            let clone = document.importNode(instBoxNode, true);
                            fillEcsBoxData(ecs, clone);
                            vswdiv.appendChild(clone);
                        }
                    }
                    if (d.rdsList.length > 0) {
                        d.rdsList.sort(getCompareFunc('dBInstanceDescription'));
                        for (let rds of d.rdsList) {
                            let clone = document.importNode(instBoxNode, true);
                            fillRdsBoxData(rds, clone);
                            vswdiv.appendChild(clone);
                        }
                    }
                    td.appendChild(vswdiv);
                });
            }
            return td;
        });

    bodyRows.insert('th', ':first-child').text(kv => kv[0]);//kv[0] is the row key
    let ecsPanelNode = document.querySelector('#template_ecs_panel').import.querySelector('.ecs-panel');

    //inst-box
    tippy('.inst-box', {
        placement: 'right',
        animateFill: false,
        interactive: true,
        trigger: 'click',
        html: function (instDiv) {
            //generate tooltip content
            switch (instDiv.getAttribute('data-InstCat')) {
                case 'ecs': {
                    let ecs = allEcs.get(instDiv.getAttribute('data-InstId'));
                    //fill in ecs data
                    let clone = document.importNode(ecsPanelNode, true);
                    // let clone = ecsPanelNode.cloneNode(true); appears to be the same effect
                    fillEcsPanelData(ecs, allEcsDisk.get(ecs.instanceId), allSG, clone);
                    updateExpand(clone);
                    applyAccordion(clone);
                    return clone;
                }
                case 'rds': {
                    let rds = allRds.get(instDiv.getAttribute('data-InstId'));
                    let clone = document.importNode(ecsPanelNode, true);
                    fillRdsPanelData(rds, clone);
                    return clone;
                }
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
            if (instance.reference && instance.reference.getAttribute('data-InstCat') === 'rds') return;

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
