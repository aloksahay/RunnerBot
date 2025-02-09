import { SecretVaultWrapper } from 'nillion-sv-wrappers';
import { orgConfig } from './nillionOrgConfig.js';

const SCHEMA_ID = '7a37fe2b-0f1d-42c7-abb5-afd41890a0af';

async function fetchData() {
    try {
        // Initialize collection
        const collection = new SecretVaultWrapper(
            orgConfig.nodes,
            orgConfig.orgCredentials,
            SCHEMA_ID
        );
        await collection.init();

        // Fetch by wallet address
        const walletData = await collection.readFromNodes({
            wallet_address: "0x123456789"
        });
        
        // Fetch by video CID
        const videoData = await collection.readFromNodes({
            video_cid: "QmTest123"
        });

        // Fetch specific record by ID
        const recordData = await collection.readFromNodes({
            _id: "060eb5cf-8ca1-4bc5-8852-3d4cdf51f21e" // use the ID from your upload
        });

        console.log('\n🔍 Data by wallet address:');
        console.log(JSON.stringify(walletData, null, 2));

        console.log('\n🎥 Data by video CID:');
        console.log(JSON.stringify(videoData, null, 2));

        console.log('\n📄 Data by record ID:');
        console.log(JSON.stringify(recordData, null, 2));

    } catch (error) {
        console.error('❌ Error fetching data:', error.message);
        process.exit(1);
    }
}

fetchData(); 