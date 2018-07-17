<%--
  Created by IntelliJ IDEA.
  User: carl
  Date: 18-7-16
  Time: 下午4:15
  To change this template use File | Settings | File Templates.
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Resource List View</title>

    <!--jquery libraries-->
    <script class="js_jquery" src="js/external/jquery/jquery-3.3.1.min.js"></script>
    <%--<script class="js_jquery" src="js/external/jquery/jquery-3.3.1.js"></script>--%>
    <script class="js_jquery_cookie" src="js/external/jquery/jquery.cookie-1.4.1.min.js"></script>
    <script class="js_jquery_ui" src="js/external/jquery/jquery-ui-1.12.1/jquery-ui.min.js"></script>

    <!--tippy libraries-->
    <%--<script class="js_tippy" src="js/external/tippy.all.min.js"></script>--%>

    <!--d3 libraries-->
    <script class="js_d3" src="js/external/d3js/d3.js"></script>

    <%--datatables libraries--%>
    <link rel="stylesheet" href="js/external/DataTables/datatables.min.css">
    <script src="js/external/DataTables/datatables.min.js"></script>

    <!--custom theme styles-->
    <link class="css_custom css_fonts" rel="stylesheet" href="css/fonts.css">
    <link class="css_custom css_table_view" rel="stylesheet" href="css/table_view.css">
    <link class="css_custom css_theme_control" rel="stylesheet" href="css/theme_control.css">
    <%--<link class="css_custom css_tippy_custom" rel="stylesheet" href="css/tippy_custom.css">--%>

    <!--custom javascripts-->
    <script class="js_custom js_btn_callbacks" src="js/btn_callbacks.js"></script>
    <script class="js_custom js_d3_chord_gen" src="js/d3_chord_gen.js"></script>
    <script class="js_custom js_helpers" src="js/helpers.js"></script>
    <script class="js_custom js_helpers_web" src="js/helpers_web.js"></script>

    <script>
        $(document).ready(function () {
            //add back button
            addHomeButton();
            //update select from cookies
            loadCookies(['target_region', 'search_cs']);
            //initialize dataTable
            initDataTables('.dataTable', false, true);
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
    <input type="button" id="btn_export" value="Export" onclick="exportToCsv()"/>
</form>

<%
    String[] p_target_region = request.getParameterValues("target_region");
    if (p_target_region == null || p_target_region.length == 0) return;
%>

<script>
    function exportToCsv() {
        let csv = 'sep=;\r\n';
        csv += cols.join(';') + '\r\n';
        rows.forEach(row => {
            csv += row.join(';').replace('\r\n', '\n') + '\r\n';
        });

        let a = document.createElement('a');
        a.setAttribute('href', 'data:application/octet-stream,' + encodeURIComponent(csv));
        a.setAttribute('download', 'ResourceList_' + region + '.csv');
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }
</script>

<script>
    'use strict';
    let region = $.cookie('target_region');
    let cache = $.cookie('refresh_cache') !== 'true';//cannot use ! to invert boolean as cookies are stored as strings

    let /**Map<string,VPC>*/ allVpc = getInstances(region, 'Vpc', null, cache, null, 'map');
    let /**Map<string,vSwitch>*/ allVsw = getInstances(region, 'Vswitch', null, cache, null, 'map');
    let /**Map<string,ECS>*/ allEcs = getInstances(region, 'Ecs', null, cache, null, 'map');
    if (allVpc.size + allVsw.size + allEcs.size === 0) throw new Error('Empty collections. Aborting.');

    let cols = ['Instance ID', 'InstanceName', 'VPC', 'vSwitch', 'Instance Type', 'Status', 'IP Addresses', 'OS', 'Creation Time', 'Price'];
    let rows = [...allEcs.values()].map((/**ECS*/ecs, i) => {
        let vpc = allVpc.get(ecs.vpcAttributes.vpcId);
        let vsw = allVsw.get(ecs.vpcAttributes.vSwitchId);
        return [
            ecs.instanceId,
            ecs.instanceName,
            vpc.vpcName + ' (' + vpc.vpcId + ')',
            vsw.vSwitchName + ' (' + vsw.vSwitchId + ')',
            ecs.instanceType,
            ecs.status,
            [...parseEcsIpAddrs(ecs).children].map(li => li.textContent),
            ecs.oSName,
            ecs.creationTime,
            '-'
        ]
    });

    let table = d3.select('body').append('table').attr('class', 'dataTable display cell-border');
    let headerRow = table.append('thead').append('tr');
    headerRow.selectAll('th')
        .data(cols).enter()
        .append('th').text(c => c);

    //body rows
    let tbody = table.append('tbody');
    let bodyRows = tbody.selectAll('tr')
        .data(rows).enter()
        .append('tr');

    bodyRows.selectAll('td')
        .data(row => row).enter()
        .append('td').text(d => d);
</script>
</body>
</html>
