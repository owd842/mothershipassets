const KOFI_VDOM_KEY = "_$kofi_vdom_"; // key used to get the previously vdom rendered in the element
const KOFI_PORTAL_KEY = "_$kofi_portal_";
const HTML_TEMPLATE_MODE = {
    TEXT: 1,
    TAG_START: 2,
    TAG_END: 3,
    PROP_NAME: 4,
    PROP_VALUE: 5,
};
const KOFI_NAMESPACES = {
    "svg": "http://www.w3.org/2000/svg",
    "xhtml": "http://www.w3.org/1999/xhtml",
    "xlink": "http://www.w3.org/1999/xlink",
    "xml": "http://www.w3.org/XML/1998/namespace",
    "xmlns": "http://www.w3.org/2000/xmlns/",
};

// @private convert an string in camelCase format to kebab-case
const camelToKebabCase = str => {
    return str.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`);
};

// remove all start and wnd whitespaces from the provided tagName
// note: tags can be also a function
const cleanTagName = tagName => {
    return typeof tagName === "string" ? tagName.replace(/^\s+|\s+$/gm, "") : tagName;
};

// extract the namespace from a node tag
// "svg:g" => ["g", "http://www.w3.org/2000/svg"]
// "svg"   => ["svg", "http://www.w3.org/2000/svg"]
// "div"   => ["div", null]
const extractNamespace = tagName => {
    // 1. tag has the namespace on it (for example 'svg:g')
    if (tagName.indexOf(":") > 1) {
        const [space, tag] = tagName.split(":");
        return [tag, KOFI_NAMESPACES[space] || null];
    }
    // 2. tag has a specific space (for example 'svg')
    else if (!!KOFI_NAMESPACES[tagName]) {
        return [tagName, KOFI_NAMESPACES[tagName]];
    }
    // namespace not necessary for the provided tag
    return [tagName, null];
};

// set a property to the element
const setProperty = (el, name, newValue = null, oldValue = null) => {
    if (name !== "key") {
        if (name === "ref") {
            if (oldValue?.current) {
                oldValue.current = null;
            }
            if (newValue && typeof newValue?.current !== "undefined") {
                newValue.current = el;
            }
        }
        else if (name === "className" || name === "class") {
            el.className = newValue || "";
        }
        else if (name === "checked" || name === "value" || name === "disabled") {
            el[name] = newValue;
        }
        else if (name === "style") {
            el.style.cssText = ""; // force to reset styles
            if (typeof newValue === "string" && !!newValue) {
                el.style.cssText = newValue;
            }
            else if (typeof newValue === "object" && !!newValue) {
                Object.keys(newValue).forEach(key => {
                    el.style[key] = newValue[key];
                });
            }
        }
        else if (name.startsWith("on")) {
            const eventName = name.slice(2).toLowerCase();
            if (typeof oldValue === "function") {
                el.removeEventListener(eventName, oldValue);
            }
            if (typeof newValue === "function") {
                el.addEventListener(eventName, newValue);
            }
        }
        else if (newValue !== null) {
            el.setAttribute(name, newValue);
        }
        else {
            el.removeAttribute(name);
        }
    }
};

// Check if there are differences between two nodes
const diff = (node1, node2) => {
    // 1. check if nodes have the same type
    if (typeof node1 !== typeof node2) { 
        return true; 
    }
    // 2. check if nodes are strings
    else if ((typeof node1 === "string" || typeof node1 === "number") && node1 !== node2) { 
        return true; 
    }
    // 3. check if nodes has not the same tag
    else if (node1.type !== node2.type) { 
        return true; 
    }
    // 4. check if nodes are portals
    else if (node1.type === KOFI_PORTAL_KEY && node1.props.parent !== node2.props.parent) {
        return true;
    }
    // 5. default, nodes are the same
    return false;
};

// @private convert a template literal to a VDOM
const compile = (h, literal, values, ctx = {i: 0, j: 0}, closing = null) => {
    const children = [];
    let mode = HTML_TEMPLATE_MODE.TEXT, buffer = "", current = null, quote = null;
    while (ctx.i < literal.length) {
        while (ctx.j < literal[ctx.i].length) {
            const char = literal[ctx.i][ctx.j];
            const nextChar = literal[ctx.i][ctx.j + 1];
            // We found a '<' character
            if (mode === HTML_TEMPLATE_MODE.TEXT && char === "<") {
                if (buffer.trim() !== "") {
                    children.push(buffer);
                }
                buffer = "";
                mode = HTML_TEMPLATE_MODE.TAG_START;
            }
            // We are in TAG_START mode and we found a '/' character with empty buffer
            else if (mode === HTML_TEMPLATE_MODE.TAG_START && char === "/" && !buffer) {
                mode = HTML_TEMPLATE_MODE.TAG_END;
            }
            // We are in TAG_START mode and we found a '/' character with non empty buffer
            else if (mode === HTML_TEMPLATE_MODE.TAG_START && char === "/" && buffer && nextChar === ">") {
                children.push(h(buffer, {}));
                buffer = "";
                mode = HTML_TEMPLATE_MODE.TEXT;
                ctx.j = ctx.j + 1; // Skip next '>'
            }
            // We are in TAG_START mode and we found a '>' character
            else if (mode === HTML_TEMPLATE_MODE.TAG_START && char === ">") {
                ctx.j = ctx.j + 1;
                children.push(h(cleanTagName(buffer), {}, ...(compile(h, literal, values, ctx, cleanTagName(buffer)) || [])));
                buffer = "";
                mode = HTML_TEMPLATE_MODE.TEXT;
            }
            // We are in TAG_START mode and we found a whitespace character
            else if (mode === HTML_TEMPLATE_MODE.TAG_START && char === " ") {
                current = [cleanTagName(buffer), {}, [], ""];
                buffer = "";
                mode = HTML_TEMPLATE_MODE.PROP_NAME;
            }
            // We are in PROP_NAME mode and we found a '/' character
            else if (mode === HTML_TEMPLATE_MODE.PROP_NAME && char === "/" && nextChar === ">") {
                if (buffer.trim() !== "") {
                    current[1][buffer.trim()] = true;
                }
                children.push(h(current[0], current[1], ...current[2]));
                current = null;
                mode = HTML_TEMPLATE_MODE.TEXT;
                buffer = "";
                ctx.j = ctx.j + 1; // Skip next '>'
            }
            // We found a '>' character and we are in property name mode
            else if (mode === HTML_TEMPLATE_MODE.PROP_NAME && char === ">") {
                if (buffer.trim() !== "") {
                    current[1][buffer.trim()] = true;
                }
                ctx.j = ctx.j + 1;
                current[2] = compile(h, literal, values, ctx, current[0]);
                children.push(h(current[0], current[1], ...current[2]));
                current = null;
                mode = HTML_TEMPLATE_MODE.TEXT;
                buffer = "";
            }
            // We found a '>' character and we are in closing tagname
            else if (mode === HTML_TEMPLATE_MODE.TAG_END && char === ">") {
                if (buffer !== closing) {
                    throw new Error(`Unexpected closing tag. Expected '${closing}' but got '${buffer}'`);
                }
                return children;
            }
            // We found a '=' character and we are in PROP_NAME mode
            else if (mode === HTML_TEMPLATE_MODE.PROP_NAME && char === "=") {
                current[3] = buffer.trim();
                buffer = "";
                mode = HTML_TEMPLATE_MODE.PROP_VALUE;
                if (nextChar === `"` || nextChar === `'`) {
                    ctx.j = ctx.j + 1;
                    quote = nextChar;
                }
            }
            // We found a whitespace character and we are in PROP_NAME mode
            else if (mode === HTML_TEMPLATE_MODE.PROP_NAME && char === " ") {
                if (buffer.trim() !== "") {
                    current[1][buffer.trim()] = true;
                }
                buffer = "";
            }
            // End of property value
            else if (mode === HTML_TEMPLATE_MODE.PROP_VALUE && char === quote) {
                current[1][current[3]] = buffer;
                quote = null;
                buffer = "";
                mode = HTML_TEMPLATE_MODE.PROP_NAME;
            }
            // Other case, save character in buffer
            else {
                buffer = buffer + char;
            }
            ctx.j++;
        }
        ctx.j = 0;
        if (ctx.i < values.length) {
            // Check if we are in PROP_VALUE mode
            if (mode === HTML_TEMPLATE_MODE.PROP_VALUE) {
                current[1][current[3]] = values[ctx.i];
                mode = HTML_TEMPLATE_MODE.PROP_NAME;
                if (literal[ctx.i + 1][ctx.j] === quote) {
                    ctx.j = ctx.j + 1;
                }
            }
            // Check if we are in PROP_NAME and current prop is '...'
            else if (mode === HTML_TEMPLATE_MODE.PROP_NAME && buffer === "...") {
                Object.assign(current[1], values[ctx.i]);
                buffer = "";
            }
            // Check if we are in TAG_START or TAG_END modes
            else if (mode === HTML_TEMPLATE_MODE.TAG_START || mode === HTML_TEMPLATE_MODE.TAG_END) {
                buffer = values[ctx.i];
            }
            // Check if we are in text mode
            else if (mode === HTML_TEMPLATE_MODE.TEXT) {
                if (buffer.trim() !== "") {
                    children.push(buffer);
                }
                children.push(values[ctx.i]);
                buffer = "";
            }
        }
        ctx.i++;
    }
    // If we are at the end of the literal and we have buffer not added
    if (buffer.trim() !== "") {
        children.push(buffer);
    }
    return children;
};

// @private mount an element
const mount = (el, parent = null) => {
    let node = null;
    // 1. check for portal element
    if (el?.type === KOFI_PORTAL_KEY) {
        node = document.createComment("kofi-portal");
        (el.children || []).forEach(childElement => {
            return mount(childElement, el.props.parent);
        });
    }
    // 2. check for text node
    else if (typeof el !== "object" || !el) {
        node = document.createTextNode(el ?? "");
    }
    // 3. other element type
    else {
        // 3.1. create the new DOM element
        const [tagName, namespace] = extractNamespace(el.type);
        node = namespace ? document.createElementNS(namespace, tagName) : document.createElement(tagName);
        // 3.2. mount children
        (el.children || []).forEach(childElement => {
            return mount(childElement, node);
        });
        // 3.3. assign element props and attributes
        Object.keys(el.props || {}).forEach(propName => {
            setProperty(node, propName, el.props[propName]);
        });
    }
    // 4. mount the new node
    if (parent) {
        parent.appendChild(node);
    }
    return node;
};

// @private update an element
const update = (parent, child, newNode, oldNode) => {
    // 1. check for no old node --> mount this new element
    if (oldNode === null || typeof oldNode === "undefined") { 
        return mount(newNode, parent);
    }
    // 2. if there is not new element --> remove the old element
    else if (newNode === null || typeof newNode === "undefined") { 
        // 2.1. we have to check if the old node is a portal
        if (oldNode.type === KOFI_PORTAL_KEY) {
            oldNode.props.parent.replaceChildren();
        }
        // 2.2. remove the child/placeholder element
        return parent.removeChild(child); 
    }
    // 3. if nodes has changed or associated key is different
    else if (diff(newNode, oldNode) || newNode?.props?.key !== oldNode?.props?.key) {
        // 3.1. check if the old node is a portal, so we have to replace the children
        if (oldNode.type === KOFI_PORTAL_KEY) {
            oldNode.props.parent.replaceChildren();
        }
        // 3.2. replace the child with the new mounted node
        return parent.replaceChild(mount(newNode), child);
    }
    // 4. check if both are portals
    else if (newNode.type === KOFI_PORTAL_KEY) {
        return update(newNode.props.parent, newNode.props.parent.childNodes[0], newNode.children[0], oldNode.children[0]);
    }
    // 5. change the properties only if element is not an string
    else if (newNode && typeof newNode !== "string") {
        // get the full properties values and update the element attributes
        const props = Object.assign({}, newNode.props, oldNode.props);
        Object.keys(props)
            .filter(name => name !== "key")
            .forEach(name => {
                const newValue = newNode.props[name];
                const oldValue = oldNode.props[name];
                // check if this property does not exists in the new element
                if (!newValue) {
                    setProperty(child, name, null, oldValue);
                }
                // check if this property exists in the old element or values are not the same
                else if (!oldValue || newValue !== oldValue) {
                    setProperty(child, name, newValue, oldValue)
                }
            });
        // update the children for all element
        const maxLength = Math.max(newNode?.children?.length || 0, oldNode?.children?.length || 0);
        const childNodes = Array.from(child.childNodes) || [];
        for (let i = 0; i < maxLength; i++) {
            const newChild = i < (newNode?.children?.length || 0) ? newNode.children[i] : null;
            const oldChild = i < (oldNode?.children?.length || 0) ? oldNode.children[i] : null;
            update(child, childNodes[i], newChild, oldChild, i);
            // update(child, childNodes[i], newNode.children?.[i] || null, oldNode.children?.[i] || null, i);
        }
    }
};

// @public main vdom element creator
const kofi = (type, props, ...children) => {
    if (type && typeof type === "string") {
        return {
            type: type.toLowerCase().trim(), 
            props: props || {}, 
            children: (children || []).flat().filter(child => {
                return child !== null && typeof child !== "undefined";
            }),
        };
    }
    // Check for function type
    else if (typeof type === "function") {
        return type(props, children);
    }
    // Other type --> throw error
    throw new Error("Invalid element type provided");
};

// @public convert a tagged template to a kofi's vdom
kofi.html = (literal, ...values) => {
    return compile(kofi, literal, values, {i: 0, j: 0}, null)[0];
};

// render an element
kofi.render = (el, parent = null) => {
    let node = null;
    // 1. no parent has been provided or is the first time the element is rendered
    if (!parent || !parent?.[KOFI_VDOM_KEY]) {
        node = mount(el, parent);
    }
    // 2. There is a previously rendered element
    if (parent && parent?.[KOFI_VDOM_KEY]) {
        update(parent, parent.childNodes[0], el, parent[KOFI_VDOM_KEY]);
    }
    // 3. save reference to the rendered tree in the parent element
    if (parent) {
        parent[KOFI_VDOM_KEY] = el;
    }
    return node;
};

// @description allow to render some children elements into a different part of the DOM
kofi.portal = (children, parent) => {
    return kofi(KOFI_PORTAL_KEY, { parent: parent }, children);
};

// generate a reference to an element
kofi.ref = () => ({current: null});

// generate a reactive state
kofi.state = (initialState = {}, changes = {}) => {
    const emitter = kofi.emitter({}, initialState);
    return Object.freeze({
        // @description get the current state
        getState: () => emitter.state,
        // @description update the current state
        setState: (newState = {}) => {
            const newStateObj = typeof newState === "function" ? newState({...emitter.state}) : newState;
            changes.current = Object.assign(changes.current || {}, newStateObj || {});
            return Promise.resolve(1).then(() => {
                if (Object.keys(changes.current || {}).length > 0) {
                    Object.assign(emitter.state, changes.current || {});
                    changes.current = {}; // reset pending changes to save
                    emitter.emit("update", emitter.state);
                }
            });
        },
        // @description register/remove update listeners
        on: listener => emitter.on("update", listener),
        off: listener => emitter.off("update", listener),
    });
};

// @description generates a tiny message bus
kofi.emitter = (initialEvents = {}, initialState = {}) => {
    const listeners = {};
    const emitter = Object.freeze({
        // @description shared object for events data
        state: Object.assign({}, initialState || {}),
        // @description register a new listener to the provided event name
        // @param name {string} event name
        // @param listener {function} listener to execute
        on: (name, listener) => {
            if (typeof name === "string" && typeof listener === "function") {
                if (typeof listeners[name] === "undefined") {
                    listeners[name] = new Set();
                }
                listeners[name].add(listener);
            }
        },
        // @description removes an event listener with the provided event name
        // @param name {string} event name
        // @param listener {function} listener to remove
        off: (name, listener) => {
            if (typeof name === "string" && typeof listener === "function") {
                if (typeof listeners[name] !== "undefined") {
                    listeners[name].delete(listener);
                }
            }
        },
        // @description dispatch an event with the provided data
        // @param name {string} name of the listeners to dispatch
        // @param data {any} data to pass to the listeners
        emit: (name, data = {}) => {
            if (typeof name === "string" && typeof listeners[name] !== "undefined") {
                Array.from(listeners[name]).forEach(listener => listener(data, emitter));
            }
        }, 
    });
    // initialize events
    if (typeof initialEvents === "object" && !!initialEvents) {
        Object.keys(initialEvents || {}).forEach(eventName => emitter.on(eventName, initialEvents[eventName]));
    }
    // return emitter instance
    return emitter;
};

// @description keep kofi.bus as an alias to kofi.emitter
kofi.bus = kofi.emitter;

// Execute the specified function when the DOM is ready
kofi.ready = fn => {
    // Resolve now if DOM has already loaded
    if (document.readyState !== "loading") {
        return fn();
    }
    // If not, wait for DOMContentLoaded event
    document.addEventListener("DOMContentLoaded", () => {
        return fn();
    });
};

// @description kofi directives
kofi.directives = {
    // @description utility method to generate random ids
    // @params {number} size - size of the generated id
    // @returns {string} uid - random string
    uid: (size = 30) => {
        const randomArray = new Uint8Array(size / 2);
        window.crypto.getRandomValues(randomArray);
        return Array.from(randomArray, d => d.toString(16).padStart(2, "0")).join("");
    },
    // @description join classNames
    classMap: (...args) => {
        const names = (args || []).map(item => {
            if (typeof item === "string") {
                return item.split(" ").filter(value => !!value);
            }
            else if (Array.isArray(item)) {
                return item.filter(value => typeof value === "string" && !!value); 
            }
            else if (typeof item === "object") {
                return Object.keys(item || {}).filter(key => !!item[key]);
            }
            // Over value --> return an empty array
            return [];
        });
        return names.flat().join(" ");
    },
    // @description join styles
    styleMap: (style = {}) => {
        return Object.keys(style).map(k => `${camelToKebabCase(k)}:${style[k]};`).join("");
    },
    // @description renders one of the both templates based on a condition
    when: (condition, trueCase, falseCase) => {
        return condition ? trueCase() : falseCase?.();
    },
};

// @deprecated: kofi.classNames has been renamed as kofi.directives.classMap
kofi.classNames = kofi.directives.classMap;

export default kofi;
