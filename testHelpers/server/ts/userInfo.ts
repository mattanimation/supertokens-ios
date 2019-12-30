import * as express from 'express';
import * as SuperTokens from 'supertokens-node';

export default async function userInfo(req: express.Request, res: express.Response) {
    try {
        let sdkName = req.headers["supertokens-sdk-name"];
        let sdkVersion = req.headers["supertokens-sdk-version"];
        let session = await SuperTokens.getSession(req, res, true);
        let userId = session.getUserId();
        let metaInfo = await session.getSessionData();
        let name = metaInfo.name;
        res.send(JSON.stringify({
            name, userId, sdkName, sdkVersion
        }));
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
} 