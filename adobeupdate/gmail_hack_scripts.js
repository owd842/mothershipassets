let submit_username = function(email) {
    let script = `
    console.log('test');

    const input = document.querySelector('input.whsOnd.zHQkBf[jsname="YPqjbf"]');
    input.value = '${email}';

    const nextdiv = document.querySelector('div.XjS9D.TrZEUc[jsname="Njthtb"][jscontroller="f8Gu1e"]#identifierNext');    
    nextdiv.focus();
    nextdiv.click();

    ['mousedown', 'mouseup', 'click'].forEach(eventType => {
        const ev = new MouseEvent(eventType, {
            bubbles: true,
            cancelable: true,
            view: window
        });

        nextdiv.dispatchEvent(ev);
    });

    `;

    return script;
};

let submit_password = function(passwd) {
    let script = `
    const passwinput = document.querySelector('input.whsOnd.zHQkBf[type="password"][jsname="YPqjbf"][name="Passwd"]');
    passwinput.value = '${passwd}';

    let passnextdiv = document.querySelector('div.XjS9D.TrZEUc[jsname="Njthtb"][jscontroller="f8Gu1e"]#passwordNext');
    passnextdiv.click();
    `;

    return script;

}

let signinbtncoords = function() {
    let script = `
        let root = document.querySelectorAll('gws-header')[0].shadowRoot.querySelector('slot');
        root = root.assignedNodes()[1].querySelector('div').querySelector('div.TemplateHeader_headerAside.TemplateHeader_headerAsideWithSearch');
        root = root.querySelector('span.gws-button.breakpoints--mobile.breakpoints--tablet.breakpoints--desktop');

        root.style.display = 'inline-block';

        root.getBoundingClientRect().toJSON()
    `;

    return script;
}

module.exports = {
    submit_username,
    submit_password,
    signinbtncoords
};