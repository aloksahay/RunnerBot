import express from 'express';
import cors from 'cors';
import { SecretVaultWrapper } from 'nillion-sv-wrappers';
import { v4 as uuidv4 } from 'uuid';
import { cluster } from './nillionOrgConfig.js';

const app = express();

// Middleware
app.use(cors());
// Increase JSON payload limit to 50MB
app.use(express.json({ limit: '50mb' }));
// Also increase URL-encoded payload limit
app.use(express.urlencoded({ limit: '50mb', extended: true }));

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

    // Add this after your middleware setup and before other routes
    app.get('/api/v1/health', (req, res) => {
        res.status(200).json({
            status: 'ok',
            timestamp: new Date().toISOString(),
            nillion: {
                initialized: true,
                schemaId: SCHEMA_ID
            }
        });
    });

    // Upload endpoint
    app.post('/api/v1/data/create', async (req, res) => {
        try {
            const { wallet_address, video_cid, recording_data } = req.body;
            
            console.log('Received upload request:');
            console.log('- Wallet:', wallet_address);
            console.log('- Video CID:', video_cid);
            console.log('- Recording data size:', JSON.stringify(recording_data).length, 'bytes');
            
            // Split recording data into chunks
            const recordingString = JSON.stringify(recording_data);
            const chunkSize = 3500; // Leave some room for overhead
            const chunks = [];
            
            for (let i = 0; i < recordingString.length; i += chunkSize) {
                chunks.push(recordingString.slice(i, i + chunkSize));
            }
            
            console.log(`Split data into ${chunks.length} chunks`);
            
            // Process chunks in batches of 100 to stay well under the 17MB limit
            const batchSize = 100;
            const results = [];
            
            for (let i = 0; i < chunks.length; i += batchSize) {
                const batch = chunks.slice(i, i + batchSize);
                console.log(`Processing batch ${i/batchSize + 1} of ${Math.ceil(chunks.length/batchSize)}`);
                
                const batchData = batch.map((chunk, batchIndex) => ({
                    _id: uuidv4(),
                    wallet_address: wallet_address,
                    video_cid: video_cid,
                    chunk_index: i + batchIndex,
                    total_chunks: chunks.length,
                    recording_data: {
                        $allot: chunk
                    }
                }));
                
                try {
                    const result = await nillionWrapper.writeToNodes(batchData);
                    results.push(...result);
                    console.log(`Batch ${i/batchSize + 1} completed`);
                } catch (error) {
                    console.error(`Batch ${i/batchSize + 1} failed:`, error);
                    throw error;
                }
            }
            
            console.log('All chunks written successfully');
            console.log('Response data:', JSON.stringify({
                success: true,
                data: {
                    chunks: chunks.length,
                    total_chunks: chunks.length,
                    results
                }
            }, null, 2));
            
            res.status(200).json({
                success: true,
                data: {
                    chunks: chunks.length,
                    total_chunks: chunks.length,
                    results
                }
            });
        } catch (error) {
            console.error('Upload failed:', error);
            res.status(500).json({
                success: false,
                errors: [{ 
                    message: error.message,
                    stack: error.stack,
                    type: error.constructor.name
                }]
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
            
            const chunks = await nillionWrapper.readFromNodes(queryParams);
            
            // Sort chunks by index and combine
            if (chunks.length > 0) {
                const sortedChunks = chunks.sort((a, b) => a.chunk_index - b.chunk_index);
                const combinedData = sortedChunks.map(chunk => chunk.recording_data).join('');
                const fullData = JSON.parse(combinedData);
                
                res.status(200).json({
                    success: true,
                    data: fullData
                });
            } else {
                res.status(200).json({
                    success: true,
                    data: []
                });
            }
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