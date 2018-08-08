/**
 * The ECS object
 * @typedef {{
 * instanceId:string,
 * instanceName:string,
 * autoReleaseTime:string,
 * clusterId:string,
 * cpu:number,
 * creationTime:string,
 * description:string,
 * eipAddress:{allocationId:string, ipAddress:string, internetChargeType:string},
 * expiredTime:string,
 * gPUAmount:number,
 * gPUSpec:string,
 * hostName:string,
 * imageId:string,
 * instanceChargeType:string,
 * instanceId:string,
 * instanceName:string,
 * instanceNetworkType:string,
 * instanceType:string,
 * instanceTypeFamily:string,
 * internetChargeType:string,
 * internetMaxBandwidthIn:number,
 * internetMaxBandwidthOut:number,
 * ioOptimized:bool,
 * memory:number,
 * networkInterfaces:Array<{macAddress:string, networkInterfaceId:string, primaryIpAddress:string}>,
 * oSName:string,
 * oSType:string,
 * publicIpAddress:Array<string>,
 * regionId:string,
 * securityGroupIds:Array<string>,
 * serialNumber:string,
 * spotPriceLimit:number,
 * spotStrategy:string,
 * startTime:string,
 * status:string,
 * stoppedMode:string,
 * tags:Array<{tagKey:string, tagValue:string}>,
 * vlanId:string,
 * vpcAttributes:{vpcId:string, vSwitchId:string, natIpAddress:string, privateIpAddress:Array<string>},
 * zoneId:string,
 * }} ECS
 */

/**
 * The VPC object
 * @typedef {{
 * cidrBlock:string,
 * creationTime:string,
 * description:string,
 * isDefault:bool,
 * regionId:string,
 * status:string,
 * vRouterId:string,
 * vSwitchIds:Array<string>,
 * vpcId:string,
 * vpcName:string
 * }} VPC
 */

/**
 * The vSwitch object
 * @typedef {{
 * availableIpAddressCount:number,
 * cidrBlock:string,
 * creationTime:string,
 * description:string,
 * isDefault:bool,
 * status:string,
 * vSwitchId:string,
 * vSwitchName:string,
 * vpcId:string,
 * zoneId:string
 * }} vSwitch
 */

/**
 * The RDS object
 * @typedef {{
 * connectionMode:string,
 * createTime:string,
 * dBInstanceClass:string,
 * dBInstanceDescription:string,
 * dBInstanceId:string,
 * dBInstanceNetType:string,
 * dBInstanceStatus:string,
 * dBInstanceType:string,
 * engine:string,
 * engineVersion:string,
 * expireTime:string,
 * insId:number,
 * instanceNetworkType:string,
 * lockMode:string,
 * lockReason:string,
 * mutriORsignle:bool,
 * payType:string,
 * readOnlyDBInstanceIds:Array<string>,
 * regionId:string,
 * resourceGroupId:string,
 * vSwitchId:string,
 * vpcCloudInstanceId:string,
 * vpcId:string,
 * zoneId:string,
 * }} RDS
 */

/**
 * The Security Group object
 * @typedef {{
 * securityGroupId:string,
 * description:string,
 * securityGroupName:string,
 * vpcId:string,
 * creationTime:string,
 * tags:Array<{tagKey:string, tagValue:string}>,
 * }} SecGrp
 */

/**
 * Set cookies with the value of the elements with specified IDs.
 * Value will be read from different properties based on the type of the element.
 * @param {Array} IDs Array of strings containing the id of the elements to set cookies for.
 */
function saveCookies(IDs) {
    let ele;
    for (let id of IDs) {
        ele = document.getElementById(id);
        if (ele == null) continue;
        switch (ele.type) {
            case 'checkbox':
                $.cookie(id, ele.checked, { expires: 30 });
                break;
            default:
                $.cookie(id, ele.value, { expires: 30 });
                break;
        }
    }
}

/**
 * Load cookies and set the value of the elements with specified IDs.
 * Different properties will be set based on the type of the element.
 * @param {Array} IDs Array of strings containing the id of the elements to set cookies for.
 */
function loadCookies(IDs) {
    let ele;
    for (let id of IDs) {
        let val = $.cookie(id);
        if (val == null) continue;
        ele = document.getElementById(id);
        if (ele == null) continue;
        switch (ele.type) {
            case 'checkbox':
                ele.checked = (val === 'true');//$.cookie() returns a string
                break;
            default:
                ele.value = val;
                break;
        }
    }
}

/**
 * @param selector jQuery selector to select the DataTables wanted.
 * @param {number | Array<number> | null} combinedCol Set to false to disable. Otherwise it is passed to update_colspan as the first parameter.
 * @param {string | Array<string> | null} combinedRow Set to false to disable. Otherwise it is passed to update_rowspan as the first parameter.
 */
function initDataTables(selector, combinedCol = null, combinedRow = null) {
    //dataTable returns jquery obj and DataTable return DataTable Api obj.
    let allDT = $(selector).DataTable({
        "paging": false,
        "colReorder": true,
        "searching": false,
    });
    if (allDT.context.length > 0) {
        try {
            //set column order from cookie (for the first table)
            let colOrder = $.cookie(allDT.context[0].sInstance + '.colReorder.order');
            allDT.colReorder.order(JSON.parse(colOrder));
        } catch (ex) {}

        if (combinedRow != null) {
            update_rowspan(combinedRow);
            allDT.on('order', function (event, settings, details) {
                update_rowspan(combinedRow);
            });
        }

        if (combinedCol != null) {
            update_colspan(combinedCol);
            //need to use column-reorder.dt if allDT is jquery object
            allDT.on('column-reorder', function (event, settings, details) {
                $.cookie(event.currentTarget.id + '.colReorder.order', JSON.stringify(allDT.colReorder.order()), { path: location.pathname });
                update_colspan(combinedCol);
            });
        }
        else {
            allDT.on('column-reorder', function (event, settings, details) {
                $.cookie(event.currentTarget.id + '.colReorder.order', JSON.stringify(allDT.colReorder.order()), { path: location.pathname });
            });
        }
    }
}

/**
 * Enable or disable the rowspan attributes on target tables.
 * @param {string | Array<string>} colNames The name of the column, or array of the names of columns to apply merging.
 * Set to the content of the th in thead, or * to apply to all columns.
 * @param table If set to null, will target all elements with dataTable class.
 * @param {function(Node): Object} contentFn The function to get the content for comparison. By default textContent is used.
 */
function update_rowspan(colNames, table = null, contentFn = a => a.textContent)
{
    if (typeof colNames === "string" && colNames !== "*") colNames = [colNames];

    let tablebodies = table == null ? $('.dataTable tbody') : $('tbody', table);

    tablebodies.toArray().forEach(body => {
        let head = body.previousElementSibling;
        if (colNames === "*") colNames = $("th", head).toArray().map(th => th.textContent);
        colNames.forEach(colName => {
            let rows = $('tr', body).toArray();
            let /**HTMLElement*/lastSpannedCell = null;
            let lastSpannedCellContent = null;
            //get the index of the target column
            let colIdxToMerge = $("th:contains('" + colName + "')", head).index();

            rows.forEach(row => {
                let cell = row.children[colIdxToMerge];
                //reset attributes for future runs
                cell.removeAttribute('rowspan');
                cell.removeAttribute('hidden');
                if (lastSpannedCell == null || contentFn(cell) !== lastSpannedCellContent) {
                    lastSpannedCell = cell;
                    lastSpannedCellContent = contentFn(cell);
                }
                else {
                    let lastSpan = lastSpannedCell.getAttribute('rowspan');
                    let newSpan = (lastSpan == null ? 2 : parseInt(lastSpan) + 1).toString();
                    lastSpannedCell.setAttribute('rowspan', newSpan);
                    cell.hidden = true;
                }
            });
        });
    });
}

/**
 * Enable or disable the colspan attributes on target tables.
 * @param {number | Array<number>} rowIndex Set to -1 to apply to all rows.
 * @param table If set to null, will target all elements with dataTable class.
 * @param {function(Node): Object} contentFn The function to get the content for comparison. By default textContent is used.
 */
function update_colspan(rowIndex, table = null, contentFn = a => a.textContent) {
    if (rowIndex == null) rowIndex = [-1];
    else if (typeof rowIndex === "number") rowIndex = [rowIndex];

    let rows = table == null ? $('.dataTable tr').toArray() : $('tr', table).toArray();

    if (rowIndex[0] !== -1) rows = rowIndex.reduce((pre, cur) => {
        let item = rows[cur];
        return item == null ? pre : (pre.push(item), pre);
    }, []);

    rows.forEach((tr, trIdx) => {
        let /**HTMLElement*/lastSpannedCell = null;
        let lastSpannedCellContent = null;
        [...tr.children].forEach((/**HTMLElement*/cell, cellIdx) => {
            //reset attributes first
            cell.removeAttribute('colspan');
            cell.removeAttribute('hidden');
            if (lastSpannedCell == null || contentFn(cell) !== lastSpannedCellContent) {
                lastSpannedCell = cell;
                lastSpannedCellContent = contentFn(cell);
            }
            else {
                let lastSpan = lastSpannedCell.getAttribute('colspan');
                let newSpan = (lastSpan == null ? 2 : parseInt(lastSpan) + 1).toString();
                lastSpannedCell.setAttribute('colspan', newSpan);
                cell.hidden = true;
            }
        });
    });
}

/**
 * Use jQuery AJAX call to AliyunApiServlet's GetInstances method synchronously with provided parameters.
 * @param {string} region
 * @param {string} reqType Needs to match AliyunApiWrappers.RequestTypes.
 * @param {object} reqParams
 * @param {boolean} cache
 * @param {Object} cacheFilter
 * @param {string} resultType The type of the result. Can be 'array', 'map' or 'keyedObject'.
 * When applicable, the instance ID will be used as the key.
 * Set to null, 'keyedObject' or anything else to use the raw format returned from AliyunApiServlet.
 * @return {(Array | Map | Object | null)}
 */
function getInstances(region, reqType, reqParams = null, cache = true, cacheFilter = null, resultType = 'array') {
    let result = null;
    $.ajax({
        type: 'POST',
        url: 'AliyunApiServlet',
        dataType: 'json',
        async: false,
        data: {
            funcName: 'GetInstances',
            args: JSON.stringify(
                [
                    region,
                    reqType,
                    reqParams,
                    cache,
                    cacheFilter
                ]),
        },
        success: function (resp) {
            if (resp.error) {
                alert('API call failed.\r\n' + resp.error);
            }
            else {
                switch (resultType) {
                    case 'array':
                        result = Object.values(resp.response);
                        break;
                    case 'map':
                        result = new Map(Object.entries(resp.response));
                        break;
                    case 'keyedObject':
                    default:
                        result = resp.response;
                        break;
                }
            }
        },
        error: function (xhr) {
            alert(`API call failed (${xhr.status}).`);
        }
    });
    return result;
}

/**
 * Use jQuery AJAX call to AliyunApiServlet's GetPrice method synchronously with provided parameters.
 * @param {string} region
 * @param {string} targetType Supported values: Ecs.
 * @param {string} targetId The ID of the target.
 * @param {Function} callback Callback function after success. Result will be passed as the first parameter. Passing this parameter will enable async.
 */
function getPrice(region, targetType, targetId, callback = null) {
    let result = null;
    $.ajax({
        type: 'POST',
        url: 'AliyunApiServlet',
        dataType: 'json',
        async: callback != null,
        data: {
            funcName: 'GetPrice',
            args: JSON.stringify(
                [
                    region,
                    targetType,
                    targetId,
                ]),
        },
        success: function (resp) {
            if (resp.error) {
                alert('API call failed.\r\n' + resp.error);
            }
            else {
                result = resp.response;
                if (callback != null) callback(result);
            }
        },
        error: function (xhr) {
            alert(`API call failed (${xhr.status}).`);
        }
    });
    return result;
}

/**
 * Return the color representing the ECS status.
 * @param status The status text.
 */
function getStatusColor(status) {
    switch (status) {
        case 'Running':
        case 'running':
            return '#006400';
        case 'Stopped':
        case 'stopped':
            return '#8b0000';
        default:
            return '#484848';
    }
}

/**
 * Return the background-image based on the ecs details. Leave parameter null to use default image / color.
 * @param {string} oSType
 * @param {string} payType
 */
function getBackImage(oSType, payType) {
    // let osColor = 'dimgray';
    let osImage = 'url(images/question.png)';
    if (oSType) {
        switch (oSType.toLowerCase()) {
            case 'linux':
                // osColor = '#bd8342';
                osImage = 'url(images/linux.png)';
                break;
            case 'windows':
                // osColor = '#3a62ba';
                osImage = 'url(images/windows.png)';
                break;
            case 'mysql':
                // osColor = '#3a62ba';
                osImage = 'url(images/mysql.png)';
                break;
        }
    }

    let payColor = 'dimgray', payImage = 'url(images/question.png)';
    if (payType) {
        switch (payType.toLowerCase()) {
            case 'prepaid':
                payColor = '#4bbfbf';
                payImage = 'url(images/piggybank.png)';
                break;
            case 'postpaid':
                payColor = '#af45a7';
                payImage = 'url(images/timer.png)';
                break;
        }
    }

    return `${osImage}, ${payImage}, linear-gradient(to right, transparent 95%, ${payColor} 95%, ${payColor})`;
}

// /**
//  * @param {MouseEvent} event
//  */
// function animBackImage(event) {
//     let ele = event.srcElement;
//     $(ele).animate({'backgroundPosition': })
// }

/**
 * Generate a ul with all IP addresses of an ECS instance.
 * @param {!Object} ecs Ecs object returned from getInstances() call.
 * @param {string} parentTag
 * @param {string} childTag
 * @return {HTMLElement}
 */
function parseEcsIpAddrs(ecs, parentTag = 'ul', childTag='li') {
    let ul = document.createElement(parentTag);
    if (Array.isArray(ecs.networkInterfaces) && ecs.networkInterfaces.length > 0) {
        for (let ni of ecs.networkInterfaces) {
            let li = document.createElement(childTag);
            li.innerText = ni.primaryIpAddress;
            ul.appendChild(li);
        }
    }
    if (Array.isArray(ecs.publicIpAddress) && ecs.publicIpAddress.length > 0) {
        for (let ip of ecs.publicIpAddress) {
            let li = document.createElement(childTag);
            li.innerText = ip + ' (Public)';
            ul.appendChild(li);
        }
    }
    if (ecs.eipAddress != null && ecs.eipAddress.ipAddress) {
        let li = document.createElement(childTag);
        li.innerText = ecs.eipAddress.ipAddress + ' (Elastic)';
        ul.appendChild(li);
    }
    return ul;
}

/**
 * Generate a ul / ol element based on the object's key and values. Nested objects will be added to nested lists.
 * @param obj
 * @param list The ul or ol element.
 */
function objToList(obj, /*HTMLElement*/ list) {
    for (let k in obj) {
        if (!obj.hasOwnProperty(k)) continue;
        let v = obj[k];
        if (v == null) v = '';

        let li = document.createElement('li');
        // li.appendChild(document.createTextNode(k));
        li.innerHTML = '<b>' + k + ': </b>';
        if (typeof v === 'object') {
            //iterate inside value
            let sublist = document.createElement(list.tagName);
            objToList(v, sublist);
            li.appendChild(sublist);
        }
        else {
            li.innerHTML += v;
        }
        list.appendChild(li);
    }
}


function addHomeButton() {
    document.body.appendChild($(parseHTMLElement(
`<img class="button" src="images/left-arrow.png" onclick="window.location.href=location.origin+'/aliyun-console/index.html'" style="
    position: fixed;
    display: none;
    right: 0.5em;
    bottom: 0.5em;
    width: 50px;">`)).fadeIn()[0]);
}
