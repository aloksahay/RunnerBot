import express from 'express';
import cors from 'cors';
import { SecretVaultWrapper } from 'nillion-sv-wrappers';
import { v4 as uuidv4 } from 'uuid';
import { cluster } from './nillionOrgConfig.js';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Debug log
console.log('Cluster config:', JSON.stringify(cluster, null, 2));

const SCHEMA_ID = cluster.schemaId;
try {
    // Create a secret vault wrapper and initialize the SecretVault collection to use
    const nillionWrapper = new SecretVaultWrapper(
        cluster.nodes,
        cluster.credentials,
        SCHEMA_ID
    );
    console.log('Wrapper created');
    await nillionWrapper.init();
    console.log('Wrapper initialized');

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

            const result = await nillionWrapper.writeToNodes([data]);
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
            
            const result = await nillionWrapper.readFromNodes(queryParams);
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
} catch (error) {
    console.error('Error initializing wrapper:', error);
    process.exit(1);
} 