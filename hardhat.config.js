require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.0",
      },
      {
        version: "0.6.5"//Only needed for MockV3Aggregator.sol. 
      },
    ],
  },
};

// module.exports = {
//   solidity: {
//     compilers: [
//       {
//         version: "0.5.5",
//       },
//       {
//         version: "0.6.7",
//         settings: {},
//       },
//     ],
//   },
// };
