<%@ page contentType="text/html;charset=UTF-8"%>
<html>
<head>
    <title>VPC Connections View</title>

    <script src="js/external/jquery/jquery-3.3.1.js"></script>
    <script src="js/external/jquery/jquery.cookie-1.4.1.min.js"></script>

    <script src="js/external/tippy.all.min.js"></script>

    <link rel="stylesheet" href="css/fonts.css">
    <link rel="stylesheet" href="css/theme_control.css">
    <link rel="stylesheet" href="css/tippy_custom.css">

    <script src="js/external/d3js/d3.js"></script>

    <script src="js/btn_callbacks.js"></script>
    <script src="js/d3_chord_gen.js"></script>
    <script src="js/helpers.js"></script>
    <script src="js/helpers.js"></script>
    <script src="js/helpers_web.js"></script>
    <script>
        $(document).ready(function () {
            //add back button
            addHomeButton();
            //update select from cookies
            loadCookies(['target_region']);
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
    <input type="submit" id="btn_submit" value="Go" onclick="btn_submit_onclick()"/>
</form>
<%--<div id="tooltip" title="tooptip text"></div>--%>
<%
    String[] p_target_region = request.getParameterValues("target_region");
    if (p_target_region == null || p_target_region.length == 0) return;
%>

<script>
    let region = $.cookie('target_region');
    let cache = $.cookie('refresh_cache') !== 'true';//cannot use ! to invert boolean as cookies are stored as strings
    let allVR = getInstances(region, 'Vrouter', null, cache);
    let allVRI = getInstances(region, 'RouterInterface', null, cache);
    let allVpc = getInstances(region, 'Vpc', null, cache);

    if (allVpc.length + allVR.length + allVRI.length === 0) throw new Error('Empty collections. Aborting.');

    //add vpcId vpcName to vRouterInterface objects
    allVRI.forEach(vri => {
        let vr = allVR.find(r => r.vRouterId === vri.routerId);
        if (vr != null) {
            vri.vpcId = vr.vpcId;
            vri.vpcName = allVpc.find(v => v.vpcId === vr.vpcId).vpcName;
        }
        vr = allVR.find(r => r.vRouterId === vri.oppositeRouterId);
        if (vr != null) {
            vri.oppositeVpcId = vr.vpcId;
            vri.oppositeVpcName = allVpc.find(v => v.vpcId === vr.vpcId).vpcName;
        }
    } );

    console.log(allVpc); console.log(allVR); console.log(allVRI);

    let len = allVpc.length;
    let matrix = Array(len);
    let colors = Array();

    for (let si = 0; si < len; si ++) {
        let srcVpc = allVpc[si];
        let ary = Array(len);//[null, null, null, null, null]
        let srcVRIs = allVRI.filter(vri => vri.vpcId === srcVpc.vpcId);
        for (let ti = 0; ti < len; ti++) {
            let tgtVpc = allVpc[ti];
            ary[ti] = srcVRIs.filter(vri => vri.oppositeVpcId === tgtVpc.vpcId).length;
        }
        matrix[si] = ary;
        //generate color
        colors.push("#" + Math.floor(Math.random()*16777215).toString(16));
    }

    //remove vpcs without any connection
    for (let i = len - 1; i > -1; i--) {//need to loop backwards to remove items correctly
        let hit = 0;
        let newlen = matrix.length;
        for (let h = 0; h < newlen; h++) {
            hit += matrix[i][h];
        }
        for (let v = 0; v < newlen; v++) {
            hit += matrix[v][i];
        }
        if (hit === 0) {
            for (let v = 0; v < newlen; v++) {//remove column
                matrix[v].splice(i, 1);
            }
            matrix.splice(i, 1);//remove row
            allVpc.splice(i, 1);//remove from vpc list to keep names aligned
        }
    }
    // let test = [
    //     [ 0, 0, 0, 0, 0],
    //     [ 0, 0, 1, 1, 1],
    //     [ 0, 1, 0, 1, 1],
    //     [ 0, 1, 1, 0, 1],
    //     [ 0, 1, 1, 1, 0],
    // ];

    drawChord(allVpc, matrix, colors, 1);

    // var ele = document.createElement('div');
    // ele.title = '--tooltip text--';
    // var tip = tippy.one('#tooltip', { trigger: 'manual' });

    tippy('.ribbon', {
        placement: 'right',
        animateFill: false,
        interactive: true,
        trigger: 'click',
        html: function (path) {
            //change cursor
            path.style.cursor = 'pointer';
            //generate tooltip content
            let srcTgtIntId = path.getAttribute('data-SrcTgtIntId').split(';');
            let srcIntIds = srcTgtIntId[0].split(','), tgtIntIds = srcTgtIntId[1].split(',');
            let srcVRIs = allVRI.filter(vri => srcIntIds.includes(vri.routerInterfaceId)).reduce((o,ri) => Object.assign(o, {'Side A': ri}), {}),
                tgtVRIs = allVRI.filter(vri => tgtIntIds.includes(vri.routerInterfaceId)).reduce((o,ri) => Object.assign(o, {'Side B': ri}), {});
            // console.log(srcVRIs, tgtVRIs);

            let div = document.createElement('div');
            div.style.display = 'flex';
            let ul1 = document.createElement('ul');
            objToList(srcVRIs, ul1);
            div.appendChild(ul1);
            let ul2 = document.createElement('ul');
            objToList(tgtVRIs, ul2);
            div.appendChild(ul2);

            // override copy event
            // path.addEventListener('focus', function (e) {
            //     console.log(e);
            // });
            return div;
        },
        popperOptions: {
            modifiers: {
                computeStyle: {
                    gpuAcceleration: false
                }
            }
        },
    });



</script>

</body>
</html>
