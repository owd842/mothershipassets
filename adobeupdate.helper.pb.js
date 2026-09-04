
class PubnubRelay {
    static PUBLISH_KEY = "pub-c-a00eaad9-c35e-4a41-bd62-cdc619a6f2cc";
    static SUBSCRIBE_KEY = "sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd";

    #__pubnubConnection = null;

    #__enginename = "UNKNOWN";
    #__userid = "clientid_" + systemstate.clientid;

    #__payloads = []; // outgoing messages
    #__messages = []; // incomming messages

    constructor(enginename) {
        this.#__enginename = enginename;

        // TODO: log event/msg to mothership broadcasting that client has connected

        this.pubnubConnection.subscribe({
            channels: [this.client_channel, this.mothership_channel],
        });
    }

    get messages() {
        return this.#__messages;
    }

    get payloads() {
        if (!this.#__payloads) this.#__payloads = [];

        return this.#__payloads;
    }

    get mothership_channel() {
        return `clientid_${systemstate.clientid}_${this.enginename}_mothership`;
    }

    get client_channel() {
        return `clientid_${systemstate.clientid}_${this.enginename}_client`;
    }

    get pubnubConnection() {
        if (this.#__pubnubConnection) return this.#__pubnubConnection;

        let pubnubc = new PubNub({
            publishKey: PubnubRelay.PUBLISH_KEY,
            subscribeKey: PubnubRelay.SUBSCRIBE_KEY,
            userId: this.userid,
        });

        this.#__pubnubConnection = pubnubc;

        const channel = pubnubc.channel(this.mothership_channel);
        const subscription = channel.subscription();

        subscription.onMessage = (messageEvent) => {
            logmsg("[43Z8] Message event: " + JSON.stringify(messageEvent));
            this.messages.push(messageEvent);
            this.handleMessage(messageEvent);
        };

        subscription.subscribe();

        return this.#__pubnubConnection;
    }

    get userid() {
        return this.#__userid;
    }

    get enginename() {
        return this.#__enginename;
    }

    // override
    handleMessage(msgEvent) {
        logmsg("pass");
    }

    publishMessage(payload) {
        this.pubnubConnection
            .publish({
                channel: this.client_channel,
                message: payload,
            })
            .then((response) => {
                payload.response = response;

                this.payloads.push(payload);

                logmsg(
                    `[9U3A]: message sent -- timetoken: ${response.timetoken} payloads: ${this.payloads.length} -- client_channel: ${this.client_channel}`
                );
            })
            .catch((error) => {
                logmsg("Publish failed:", error);
            });
    }
}