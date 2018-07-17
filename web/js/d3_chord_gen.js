// import * as d3 from './external/d3js/d3';
/**
 * Append an svg to the body of the HTML.
 * @param {Array} names Array of strings with the name of each group.
 * @param {Array} matrix Two-dimensional array with same number of columns and rows as the groups. Values are the size of each end.
 * @param {Array} colors Array of color strings for each group.
 * @param {Number} padding Angle space between each group.
 */
function drawChord(names, matrix, colors, padding) {
    let width = 900, height = 900;
    let innerRadius = width / 2 * 0.8;
    let outerRadius = innerRadius * 1.08;

    // let names = ['PRD', 'QLT', 'DEV' ,'SEC', 'Test'];
    // let matrix = [
    //     [ 0,  1,  1,  1,  1],
    //     [ 1,  0,  1,  1,  1],
    //     [ 1,  1,  0,  1,  1],
    //     [ 1,  1,  1,  0,  1],
    //     [ 1,  1,  1,  1,  0],
    // ];
    // let colors = ["#0003a8", "#af0004", "#009511", "#00b3af", "#b9b300"];

    let svg = d3.select("body").append("svg")
        .attr("width", width)
        .attr("height", height);

    let chord = d3.chord()
        .padAngle(padding)
        .sortSubgroups(d3.descending)(matrix);

    let arc = d3.arc()
        .innerRadius(innerRadius)
        .outerRadius(outerRadius);

    let ribbon = d3.ribbon()
        .radius(innerRadius);

// let colors = d3.scaleOrdinal()
//     .domain(d3.range(5))
//     .range(["#0050ff", "#FFDD89", "#957244", "#F26223", "#ff3799"]);

    /////////////// Create the gradient fills //////////////////
    //Function to create the unique id for each chord gradient
    function getGradID(d) { return "linkGrad-" + d.source.index + "-" + d.target.index; }

    //Create the gradients definitions for each chord
    let grads = svg.append("defs").selectAll("linearGradient")
        .data(chord)
        .enter().append("linearGradient")
        //Create the unique ID for this specific source-target pairing
        .attr("id", getGradID)
        .attr("gradientUnits", "userSpaceOnUse")
        //Find the location where the source chord starts
        .attr("x1", d => innerRadius * Math.cos((d.source.endAngle-d.source.startAngle)/2 + d.source.startAngle - Math.PI/2))
        .attr("y1", d => innerRadius * Math.sin((d.source.endAngle-d.source.startAngle)/2 + d.source.startAngle - Math.PI/2))
        //Find the location where the target chord starts
        .attr("x2", d => innerRadius * Math.cos((d.target.endAngle-d.target.startAngle)/2 + d.target.startAngle - Math.PI/2))
        .attr("y2", d => innerRadius * Math.sin((d.target.endAngle-d.target.startAngle)/2 + d.target.startAngle - Math.PI/2));

    //Set the starting color (at 0%)
    grads.append("stop")
        .attr("offset", "0%")
        .attr("stop-color", function(d){ return colors[d.source.index]; });

    //Set the ending color (at 100%)
    grads.append("stop")
        .attr("offset", "100%")
        .attr("stop-color", function(d){ return colors[d.target.index]; });

    /////////////// Draw the graph //////////////////
    //the whole graph
    let graph = svg.append("g")
        .attr("transform", "translate(" + width/2 + "," + height/2 + ")")
        .datum(chord);

    //the outer ring (donut body)
    let group = graph.append("g")
        .attr("class", "groups")
        .selectAll("g")
        .data(chords => chords.groups)
        .enter().append("g")
        .on("mouseover", fadeOtherGroups(0.1))
        .on("mouseout", fadeOtherGroups(1));

    //create the donut body
    group.append("path")
        .style("fill", d => colors[d.index])
        .attr("d", arc)
        .each(function(d,i) {
        //Search pattern for everything between the start and the first capital L
        let firstArcSection = /(^.+?)L/;

        //Grab everything up to the first Line statement
        let newArc = firstArcSection.exec( d3.select(this).attr("d") )[1];
        //Replace all the comma's so that IE can handle it
        newArc = newArc.replace(/,/g , " ");

        //If the end angle lies beyond a quarter of a circle (90 degrees or pi/2)
        //flip the end and start position
        if (d.endAngle > 90*Math.PI/180 & d.startAngle < 270*Math.PI/180) {
            let startLoc 	= /M(.*?)A/,		//Everything between the first capital M and first capital A
                middleLoc 	= /A(.*?)0 0 1/,	//Everything between the first capital A and 0 0 1
                endLoc 		= /0 0 1 (.*?)$/;	//Everything between the first 0 0 1 and the end of the string (denoted by $)
            //Flip the direction of the arc by switching the start en end point (and sweep flag)
            //of those elements that are below the horizontal line
            let newStart = endLoc.exec( newArc )[1];
            let newEnd = startLoc.exec( newArc )[1];
            let middleSec = middleLoc.exec( newArc )[1];

            //Build up the new arc notation, set the sweep-flag to 0
            newArc = "M" + newStart + "A" + middleSec + "0 0 0 " + newEnd;
        }//if

        //Create a new invisible arc that the text can flow along
        svg.append("path")
            .attr("class", "hiddenArcs")
            .attr("id", "arc"+i)
            .attr("d", newArc)
            .style("fill", "none");
        });

    //group name text
    group.append("text")
        .attr("class", "titles")
        .attr("dy", function(d,i) { return (d.endAngle > 90*Math.PI/180 && d.startAngle < 270*Math.PI/180 ? 25 : -16); })
        .append("textPath")
        .attr("startOffset","50%")
        .style("text-anchor","middle")
        .attr("href",function(d,i){return "#arc"+i;})
        .text(d => names[d.index].vpcName);

/*  these place text without following the outer arc.
    group.append("text")
        .text(d => names[d.index].vpcName)
        .each(d => d.angle = (d.startAngle + d.endAngle) / 2)
        .attr("dy", ".35em")
        .attr("transform", d =>
        {
            let low = Math.PI * 2 * 0.25, high = Math.PI * 2 * 0.75;
            return "rotate(" + (d.angle * 180 / Math.PI - 90) + ")"
                + "translate(" + (outerRadius + 10) + ")"
                + ((d.angle > low && d.angle < high) ? "rotate(-90)" : "rotate(90)");
        })
        // .style("text-anchor", d => d.angle > Math.PI ? "end" : null)
        .style("text-anchor", "middle");*/

    // create the connections inside
    graph.append("g")
        .attr("class", "ribbons")
        .style("fill-opacity", 0.7)
        .selectAll("path")
        .data(chords => chords).enter()
        .append("path")
        .attr("class", "ribbon")
        .attr("data-SrcTgtIntId", d => {
            let srcVpcId = allVpc[d.source.index].vpcId;
            let tgtVpcId = allVpc[d.target.index].vpcId;
            let srcVRI = allVRI.filter(vri => vri.vpcId === srcVpcId && vri.oppositeVpcId === tgtVpcId);
            let tgtVRI = allVRI.filter(vri => vri.vpcId === tgtVpcId && vri.oppositeVpcId === srcVpcId);
            return srcVRI.map(vri => vri.routerInterfaceId).join() + ';' + tgtVRI.map(vri => vri.routerInterfaceId).join();
        })
        .attr("d", ribbon)
        // .style("stroke", d => d3.rgb(colors[d.target.index]).darker())
        .style("fill", d => "url(#" + getGradID(d) + ")")
        // .style("fill", d => colors[d.target.index]);
        .on("mouseover", fadeOtherRibbons(0.1))
        .on("mouseout", fadeOtherRibbons(1));

    function fadeOtherGroups(opacity) {
        return function(d,i) {
            svg.selectAll(".ribbons path")
                .filter(function(d) { return d.source.index !== i && d.target.index !== i; })
                .transition()
                .style("opacity", opacity);
        };
    }

    function fadeOtherRibbons(opacity) {
        return function(d,curRbnIdx) {
            svg.selectAll(".ribbons path")
                .filter((d, i) => i !== curRbnIdx)
                .transition()
                .style("opacity", opacity);
        };
    }

}
