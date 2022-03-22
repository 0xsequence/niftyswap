const ethers = require('ethers')
const { promises: { readdir, readFile } } = require('fs')

const max = 24576

let bad = 0

async function main() {
  // List all .json files on src/artifacts
  const packages = await readdir('./src/artifacts/contracts', { withFileTypes: true })

  // Fot every package, get all contracts inside it
  for (const package of packages) {
    if (package.isDirectory()) {
      const contracts = await readdir(`./src/artifacts/contracts/${package.name}`, { withFileTypes: true })
      // For every contract, read the artifact
      for (const contract of contracts) {
        if (contract.isDirectory()) {
          const artifact = JSON.parse(await readFile(`./src/artifacts/contracts/${package.name}/${contract.name}/${contract.name.replace('.sol', '.json')}`))

          // If bytecode is undefined or empty, skip
          if (!artifact.deployedBytecode || artifact.deployedBytecode === "0x") {
            continue
          }

          // Parse deployed bytecode
          const bytecode = ethers.utils.arrayify(artifact.deployedBytecode)

          // If bytecode is bigger than max, print bad message
          if (bytecode.length > max) {
            console.log(`❌ ${package.name}/${contract.name}.json (${bytecode.length} bytes)`)
            bad++
          } else {
            console.log(`✅ ${package.name}/${contract.name}.json (${bytecode.length} bytes)`)
          }
        }
      }
    }
  }

  if (bad > 0) {
    console.log(`\n❌ ${bad} contracts are bigger than ${max} bytes`)
    process.exit(1)
  } else {
    console.log('\n✅ All contracts are smaller than 25k bytes')
    process.exit(0)
  }
}

main()
