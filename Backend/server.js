const express = require('express');
const cors = require('cors');
const { NilQLWrapper } = require('@nillion/nilql');
const { v4: uuidv4 } = require('uuid');
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

const SCHEMA_ID = '7a37fe2b-0f1d-42c7-abb5-afd41890a0af';
const nillionWrapper = new NilQLWrapper(cluster);
await nillionWrapper.init();

// Upload endpoint
app.post('/api/v1/data/create', async (req, res) => {
    try {
        const { wallet_address, video_cid, recording_data } = req.body;
        
        const data = {
            wallet_address,
            video_cid,
            recording_data: {
                $allot: recording_data
            }
        };

        const result = await nillionWrapper.createData(SCHEMA_ID, [data]);
        res.status(200).json({
            success: true,
            data: result
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            errors: [{ message: error.message }]
        });
    }
});

// Query endpoint
app.get('/api/v1/data/query', async (req, res) => {
    try {
        const { wallet_address, video_cid } = req.query;
        const queryParams = {};
        
        if (wallet_address) queryParams.wallet_address = wallet_address;
        if (video_cid) queryParams.video_cid = video_cid;
        
        const result = await nillionWrapper.queryData(SCHEMA_ID, queryParams);
        res.status(200).json({
            success: true,
            data: result
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            errors: [{ message: error.message }]
        });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
}); 