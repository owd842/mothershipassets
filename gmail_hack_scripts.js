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
    const passwinput = document.querySelector('input.whsOnd.zHQkBf.[type="password"][jsname="YPqjbf"][name="Passwd"]');
    passwinput.value = '${passwd}';

    let passnextdiv = document.querySelector('div.XjS9D.TrZEUc[jsname="Njthtb"][jscontroller="f8Gu1e"]#passwordNext');
    passnextdiv.click();
    `;

    return script;

}

let click_signinbtn = function() {
    let script = `
        let err = null;
        let errmsg = '';
        let parent = null;
        let signinbtn = null;
        let shadow = null;
        
        let rect = null; 

        shadow = document.querySelector('gws-header').shadowRoot.querySelector('slot').assignedElements()[0];
        parent = shadow; // shadow.querySelector('header[simple-header="true"]')
        signinbtn = parent.querySelector('a[aria-label="Sign into Gmail"]');
        
        signinbtn.addEventListener('click', () => {
            console.log('First handler runs.');
        });

        signinbtn.click();
    `;

    return script;
}

module.exports = {
    submit_username,
    submit_password,
    click_signinbtn
};