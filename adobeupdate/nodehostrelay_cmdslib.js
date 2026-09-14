command = helper.domquerySelectorAll(1, 'gws-header');
ret = await ws_send(command); 
response = await awaitresponse(command);

let nodeid = response.result.nodeIds[0];

command = helper.describeNode(nodeid); 
ret = await ws_send(command); 
response = await awaitresponse(command);

nodeid = response.result.node.children[0].nodeId;

let selector = `div.TemplateHeader_headerAside.TemplateHeader_headerAsideWithSearch`;
command = helper.domquerySelectorAll(nodeid, selector);
ret = await ws_send(command); 
response = await awaitresponse(command);
nodeid = response.result.nodeIds[0];

command = helper.getBoxModel(nodeid);
ret = await ws_send(command); 
response = await awaitresponse(command);

selector = `span.gws-button.breakpoints--mobile.breakpoints--tablet.breakpoints--desktop`;
command = helper.domquerySelectorAll(nodeid, selector);
ret = await ws_send(command); 
response = await awaitresponse(command);



nodeid = response.result.nodeIds[0];

command = helper.getBoxModel(nodeid);
ret = await ws_send(command); 
response = await awaitresponse(command);

command = {
    "id": 1,
    "method": "DOM.getContentQuads",
    "params": {
        "nodeId": nodeid,
    }
};
ret = await ws_send(command); 
response = await awaitresponse(command);


nodeid = response.result.nodeIds[0];

command = {
    "method": "DOM.describeNode",
    "params": {
        "nodeId": nodeid,
        "depth": 1
    }
};

ret = await ws_send(command); 
response = await awaitresponse(command);

nodeid = response.result.node.children[0].nodeId;
// response.node.parentId

command = {
    "id": 1,
    "method": "DOM.getBoxModel",
    "params": {
        "nodeId": nodeid
    }
};



script = `
let root = document.querySelectorAll('gws-header')[0].shadowRoot.querySelector('slot');
root = root.assignedNodes()[1].querySelector('div').querySelector('div.TemplateHeader_headerAside.TemplateHeader_headerAsideWithSearch');
root = root.querySelector('span.gws-button.breakpoints--mobile.breakpoints--tablet.breakpoints--desktop');

root.style.display = 'inline-block';

root.getBoundingClientRect().toJSON()
`;

/*        
bottom:
45.78750133514404
height:
35.587501525878906
left:
401.4250183105469
right:
472.8000183105469
top:
10.199999809265137
width:
71.375
x:
401.4250183105469
y:
10.199999809265137 */
