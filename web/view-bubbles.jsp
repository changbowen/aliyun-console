<%@ page contentType="text/html;charset=UTF-8"%>
<html>
<head>
    <title>Bubbles View</title>

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
    <script src="js/helpers_web.js"></script>
    <script>
        $(document).ready(function () {
            //add back button
            addHomeButton();
            //update select from cookies
            loadCookies(['target_region']);
        });
    </script>

    <style>
        .node {
            cursor: pointer;
        }

        .node:hover {
            stroke: #000;
            stroke-width: 1.5px;
        }

        .node--leaf {
            fill: white;
        }

        .label {
            font: 11px "Helvetica Neue", Helvetica, Arial, sans-serif;
            text-anchor: middle;
            text-shadow: 0 1px 0 #fff, 1px 0 0 #fff, -1px 0 0 #fff, 0 -1px 0 #fff;
        }

        .label,
        .node--root,
        .node--leaf {
            pointer-events: none;
        }
    </style>
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
<svg width="1000" height="1000"></svg>
<%--<div id="tooltip" title="tooptip text"></div>--%>
<%
    String[] p_target_region = request.getParameterValues("target_region");
    if (p_target_region == null || p_target_region.length == 0) return;
%>

<script>
    let region = $.cookie('target_region');
    let cache = $.cookie('refresh_cache') !== 'true';//cannot use ! to invert boolean as cookies are stored as strings

    let allVpc = getInstances(region, 'Vpc', null, cache);
    let allVsw = getInstances(region, 'Vswitch', null, cache);
    let allEcs = getInstances(region, 'Ecs', null, cache);

    if (allVpc.length + allVsw.length + allEcs.length === 0) throw new Error('Empty collections. Aborting.');

    let lst = { 'name': 'Aliyun', 'children':[] };
    lst.children = allVpc.map(vpc =>
    {
        return {
            'name': vpc.vpcName,
            'id': vpc.vpcId,
            'children': allVsw.reduce((result_vsw,vsw) =>
            {
                if (vsw.vpcId === vpc.vpcId) {
                    result_vsw.push({
                        'name': vsw.vSwitchName,
                        'id': vsw.vSwitchId,
                        'children':allEcs.reduce((result_ecs, ecs) =>
                        {
                            if (ecs.vpcAttributes != null && ecs.vpcAttributes.vSwitchId === vsw.vSwitchId) {
                                let size = 1000;
                                if (ecs.instanceType.includes('tiny')) {
                                    size = 200;
                                }
                                else if (ecs.instanceType.includes('small')) {
                                    size = 400;
                                }
                                else if (ecs.instanceType.includes('medium')) {
                                    size = 600;
                                }
                                else if (ecs.instanceType.includes('large')) {
                                    size = 800;
                                }

                                result_ecs.push({
                                    'name':ecs.instanceName,
                                    'id': ecs.instanceId,
                                    'size': size,
                                })
                            }
                            return result_ecs;
                        }, [])
                    })
                }
                return result_vsw;
            }, [])
        };
    });


    let svg = d3.select("svg"),
        margin = 20,
        diameter = +svg.attr("width"),// + converts to numeric
        g = svg.append("g").attr("transform", "translate(" + diameter / 2 + "," + diameter / 2 + ")");

    let color = d3.scaleLinear()
        .domain([-1, 5])
        .range(["hsl(152,80%,80%)", "hsl(228,30%,40%)"])
        .interpolate(d3.interpolateHcl);

    let pack = d3.pack()
        .size([diameter - margin, diameter - margin])
        .padding(2);

    draw(null, lst);
    function draw(error, root) {
        if (error) throw error;

        root = d3.hierarchy(root)
            .sum(function(d) { return d.size; })
            .sort(function(a, b) { return b.value - a.value; });

        let focus = root,
            nodes = pack(root).descendants(),
            view;

        let circle = g.selectAll("circle")
            .data(nodes)
            .enter().append("circle")
            .attr("class", function(d) { return d.parent ? d.children ? "node" : "node node--leaf" : "node node--root"; })
            .style("fill", function(d) { return d.children ? color(d.depth) : null; })
            .on("click", function(d) { if (focus !== d) zoom(d), d3.event.stopPropagation(); });

        let text = g.selectAll("text")
            .data(nodes)
            .enter().append("text")
            .attr("class", "label")
            .style("fill-opacity", function(d) { return d.parent === root ? 1 : 0; })
            .style("display", function(d) { return d.parent === root ? "inline" : "none"; })
            .text(function(d) { return d.data.name; });

        let node = g.selectAll("circle,text");

        svg
            .style("background", color(-1))
            .on("click", function() { zoom(root); });

        zoomTo([root.x, root.y, root.r * 2 + margin]);

        function zoom(d) {
            let focus0 = focus; focus = d;

            let transition = d3.transition()
                .duration(d3.event.altKey ? 7500 : 750)
                .tween("zoom", function(d) {
                    let i = d3.interpolateZoom(view, [focus.x, focus.y, focus.r * 2 + margin]);
                    return function(t) { zoomTo(i(t)); };
                });

            transition.selectAll("text")
                .filter(function(d) { return d.parent === focus || this.style.display === "inline"; })
                .style("fill-opacity", function(d) { return d.parent === focus ? 1 : 0; })
                .on("start", function(d) { if (d.parent === focus) this.style.display = "inline"; })
                .on("end", function(d) { if (d.parent !== focus) this.style.display = "none"; });
        }

        function zoomTo(v) {
            let k = diameter / v[2]; view = v;
            node.attr("transform", function(d) { return "translate(" + (d.x - v[0]) * k + "," + (d.y - v[1]) * k + ")"; });
            circle.attr("r", function(d) { return d.r * k; });
        }

    }
</script>

</body>
</html>
