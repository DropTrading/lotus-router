const fs = require('fs');
const path = require('path');

const artifactsDir = path.join(__dirname, 'out');

const contracts = [
    'LotusRouterEncoder'
];

const outputPath = path.join(__dirname, 'bytecode-lotus.json');
const outputJSON = {};

for (let contract of contracts) {
    const file = path.join(artifactsDir, contract.concat('.sol'), contract.concat('.json'));
    const { bytecode } = require(file);
    outputJSON[contract] = bytecode.object;
}

fs.writeFileSync(outputPath, JSON.stringify(outputJSON, null, 2));