function btn_submit_onclick() {
    document.getElementById('btn_submit').value = 'Wait...';
    saveCookies(['target_region', 'price_multi', 'combine_row', 'refresh_cache'])
}

function filter(/**string*/filterStr) {

}

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
