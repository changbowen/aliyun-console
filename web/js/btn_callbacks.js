function btn_submit_onclick() {
    document.getElementById('btn_submit').value = 'Wait...';
    saveCookies(['target_region', 'price_multi', 'search_cs', 'refresh_cache'])
}


/*function btn_pwr_onclick(btn_pwr)
{
    //authenticate if needed
    let sessionId = $.cookie('sessionId');
    let secret;
    if (sessionId == null || sessionId === '')
    {
        secret = prompt('Please enter the secret for the actions.');
        if (secret == null || secret === '') return;
    }
    $.ajax({
        type: 'POST',
        url: 'auth.php',
        dataType: 'json',
        data:
            {
                action: 'authenticate',
                sessionId: sessionId,
                secret: secret
            },
        success: function (resp_auth)
        {
            if (resp_auth.result === true)
            {
                let instanceId = btn_pwr.name.substring(12);
                if (!confirm('Are you sure you want to perform the following operations?\r\n' + btn_pwr.value + ': ' + instanceId)) return;

                //cache btn_pwr values
                let btn_action = btn_pwr.value;
                let btn_data_fnname = btn_pwr.getAttribute('data-fnname');//btn_pwr.dataset.fnname not supported by IE?
                let btn_pwr_all = document.getElementsByName('btn_ecs_pwr_' + instanceId);
                btn_pwr_all.forEach(function (btn)
                {
                    btn.value = "Wait...";
                    btn.disabled = true;
                });

                //calling API
                $.ajax({
                    type: 'POST',
                    url: 'AliyunApiWrappers.php',
                    dataType: 'json',
                    data:
                        {
                            funcName: btn_data_fnname,
                            //below php codes need to be placed after the session variable is updated.
                            args: [ document.getElementById('target_region').value, instanceId ]
                        },
                    success: function (resp_pwr)
                    {
                        if (resp_pwr.error) {
                            alert('Operation failed (' + resp_pwr.error.code + ')\r\n' +
                                resp_pwr.error.msg);
                        }
                        else {
                            alert('Operation completed successfully.');

                            //change the status text in table row temporarily
                            let tr = $('.dataTable tbody tr[data-instanceId="'+instanceId+'"]')[0];
                            let td = $('td[data-propName="Status"]', tr)[0];
                            if (td != null) td.innerHTML = btn_action + ' Requested';

                            //change the status text in tooltip temporarily
                            let li = $('.tooltiptext[data-instanceId="'+instanceId+'"] strong:contains("Status")').parent()[0];
                            if (li != null) li.innerHTML = '<strong>Status:</strong> ' + btn_action + ' Requested';

                            //refresh status after some time
                            setTimeout(function (insId) {
                                $.ajax({
                                    type: 'POST',
                                    url: 'AliyunApiWrappers.php',
                                    dataType: 'json',
                                    data:
                                        {
                                            funcName: 'GetInstances',
                                            args: [
                                                $.cookie('target_region'),
                                                0,//reqType Ecs
                                                {'InstanceIds': [insId]},
                                                0//passing 0 instead of false which will evaluate to string
                                            ]
                                        },
                                    success: function (resp_refresh) {
                                        //update row values
                                        if (resp_refresh.error) {
                                            alert('Updating instance details failed (' + resp_refresh.error.code + ')\r\n' +
                                                resp_refresh.error.msg);
                                        }
                                        else {
                                            let ecs = resp_refresh.response[insId];
                                            if (td != null) td.innerHTML = ecs['Status'];

                                            //update tooltip color (vpc view)
                                            let tip = $('.tooltip[data-instanceId="'+insId+'"]')[0];
                                            if (tip != null)
                                            {
                                                switch (ecs['Status'])
                                                {
                                                    case 'Running':
                                                        tip.style.background = 'darkgreen';
                                                        break;
                                                    case 'Stopped':
                                                        tip.style.background = 'darkred';
                                                        break;
                                                    default:
                                                        tip.style.background = '#222222';
                                                        break;
                                                }
                                            }

                                            //update tooltiptext
                                            let li = $('.tooltiptext[data-instanceId="'+insId+'"] strong:contains("Status")').parent()[0];
                                            if (li != null) li.innerHTML = '<strong>Status:</strong> ' + ecs['Status'];

                                            //recreate the power button
                                            $.ajax({
                                                type: 'POST',
                                                url: 'AliyunApiWrappers.php',
                                                dataType: 'json',
                                                data:
                                                    {
                                                        funcName: 'genBtnPower',
                                                        args: [ecs]
                                                    },
                                                success: function (resp_pwr) {
                                                    if (resp_pwr.response) {
                                                        btn_pwr_all.forEach(function (btn) {
                                                            btn.outerHTML = resp_pwr.response;
                                                        });
                                                    }
                                                }
                                            })
                                            // console.log(resp_refresh);
                                        }
                                    }
                                });
                            }, 20000, instanceId);
                        }
                    }
                });
            }
            else
            {
                alert('Authentication failed. Please contact your system administrator.\r\n' + resp_auth.msg);
            }
        }
    });
}*/

function update_price(tableClass, multiplier)
{
    let rows = $('.' + tableClass + ' tbody tr');
    if (rows.length === 0) return;

    let per = '';
    switch (multiplier) {
        case '1':
            per = ' / Hour';
            break;
        case '24':
            per = ' / Day';
            break;
        case '720':
            per = ' / Month';
            break;
        case '8640':
            per = ' / Year';
            break;
        default:
            multiplier = 1;
            per = ' / Hour';
    }

    let total = 0;
    let currency = '';
    rows.each(function () {
        let pricecell = $('td[data-hourlyValue][data-propName="Price"]', this)[0];//without get this is only a query object
        if (pricecell == null) return;
        if (pricecell.getAttribute('data-chargeType') !== 'PostPaid') return;//only applies to postpaid instances
        //get hourly price
        let price = pricecell.getAttribute('data-hourlyValue') * multiplier;
        //get currency
        currency = pricecell.getAttribute('data-currency');
        //update price cell
        pricecell.innerHTML = currency + ' ' + price.toFixed(2);

        //only calculate when instance is being charged
        let statuscell = $('td[data-propName="Status"]', this)[0];
        if (statuscell != null && statuscell.innerHTML === 'Running') total += price;
    });

    if (document.getElementById('total_price') == null) return;
    document.getElementById('total_price').innerHTML = total.toFixed(2) + ' ' + currency + per;
}
