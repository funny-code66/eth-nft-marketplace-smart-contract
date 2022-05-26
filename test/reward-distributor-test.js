const { expect } = require('chai')
const { parseEther } = require('ethers/lib/utils')
const { ethers } = require('hardhat')

describe('Pull-based Reward Distributor Smart Contract', () => {
  let RewardDistributorFactory, TestTokenFactory
  let rewardDistributor, testToken
  let accounts

  before(async () => {
    accounts = await ethers.getSigners()

    RewardDistributorFactory = await ethers.getContractFactory('RewardDistributor')
    TestTokenFactory = await ethers.getContractFactory('TestToken')
  })

  beforeEach(async () => {
    testToken = await TestTokenFactory.connect(accounts[3]).deploy()
    await testToken.deployed()
    rewardDistributor = await RewardDistributorFactory.connect(accounts[3]).deploy(testToken.address)
    await rewardDistributor.deployed()
    await (await testToken.connect(accounts[0]).mint(100)).wait()
    await (await testToken.connect(accounts[0]).approve(rewardDistributor.address, 100)).wait()
    await (await testToken.connect(accounts[1]).mint(100)).wait()
    await (await testToken.connect(accounts[1]).approve(rewardDistributor.address, 100)).wait()
    await (await testToken.connect(accounts[2]).mint(100)).wait()
    await (await testToken.connect(accounts[2]).approve(rewardDistributor.address, 100)).wait()
    await (await testToken.connect(accounts[3]).mint(100)).wait()
    // developer account
    await (await testToken.connect(accounts[3]).approve(rewardDistributor.address, 100)).wait()
    await (await testToken.connect(accounts[3]).transfer(rewardDistributor.address, 100)).wait()
  })

  it('Check status of TestToken', async () => {
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(100)
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(100)
    expect(await rewardDistributor.token()).to.equal(testToken.address)
  })

  it('Check stake in RewardDistributor', async () => {
    await (await rewardDistributor.connect(accounts[0]).stake(10)).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(90)
    await (await rewardDistributor.connect(accounts[1]).stake(20)).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(80)
  })

  it('Check stake, unstake in RewardDistributor', async () => {
    await (await rewardDistributor.connect(accounts[0]).stake(10)).wait()
    await (await rewardDistributor.connect(accounts[0]).unstake(10)).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(100)
    await (await rewardDistributor.connect(accounts[1]).stake(20)).wait()
    await (await rewardDistributor.connect(accounts[1]).unstake(20)).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(100)
  })

  it('Check canStake() in RewardDistributor', async () => {
    await (await rewardDistributor.connect(accounts[0]).stake(10)).wait()
    await (await rewardDistributor.connect(accounts[1]).stake(20)).wait()
    await (await rewardDistributor.connect(accounts[3]).distribute(3)).wait()
    expect(await rewardDistributor.connect(accounts[0]).canStake()).to.equal(11)
    expect(await rewardDistributor.connect(accounts[1]).canStake()).to.equal(22)
  })

  it('Check stake, unstakeAll, distribute in RewardDistributor', async () => {
    await (await rewardDistributor.connect(accounts[0]).stake(10)).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(90)
    await (await rewardDistributor.connect(accounts[1]).stake(20)).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(80)
    await (await rewardDistributor.connect(accounts[3]).distribute(3)).wait()
    await (await rewardDistributor.connect(accounts[0]).unstakeAll()).wait()
    await (await rewardDistributor.connect(accounts[1]).unstakeAll()).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(101)
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(102)
  })

  it('Check stake, unstake, distribute in RewardDistributor', async () => {
    await (await rewardDistributor.connect(accounts[0]).stake(10)).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(90)
    await (await rewardDistributor.connect(accounts[1]).stake(20)).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(80)
    await (await rewardDistributor.connect(accounts[3]).distribute(3)).wait()
    // after distribution
    await (await rewardDistributor.connect(accounts[0]).unstakeAll()).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(101)
    expect(await rewardDistributor.connect(accounts[1]).canStake()).to.equal(22)
    await (await rewardDistributor.connect(accounts[1]).unstake(10)).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(91)
    expect(await rewardDistributor.connect(accounts[1]).canStake()).to.equal(10)
    await (await rewardDistributor.connect(accounts[1]).unstake(10)).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(101)
  })

  it('Check stake, unstakeAll, distribute for various users and multiple times in RewardDistributor', async () => {
    await (await rewardDistributor.connect(accounts[0]).stake(10)).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(90)
    await (await rewardDistributor.connect(accounts[1]).stake(20)).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(80)
    // 1st distribution
    await (await rewardDistributor.connect(accounts[3]).distribute(3)).wait()
    expect(await rewardDistributor.connect(accounts[0]).canStake()).to.equal(11)
    expect(await rewardDistributor.connect(accounts[1]).canStake()).to.equal(22)

    await (await rewardDistributor.connect(accounts[2]).stake(30)).wait()
    expect(await testToken.balanceOf(accounts[2].address)).to.equal(70)
    // 2nd distribution
    await (await rewardDistributor.connect(accounts[3]).distribute(6)).wait()
    expect(await rewardDistributor.connect(accounts[0]).canStake()).to.equal(12)
    expect(await rewardDistributor.connect(accounts[1]).canStake()).to.equal(24)
    expect(await rewardDistributor.connect(accounts[2]).canStake()).to.equal(33)

    await (await rewardDistributor.connect(accounts[0]).unstakeAll()).wait()
    expect(await testToken.balanceOf(accounts[0].address)).to.equal(102)
    await (await rewardDistributor.connect(accounts[1]).unstakeAll()).wait()
    expect(await testToken.balanceOf(accounts[1].address)).to.equal(104)
    await (await rewardDistributor.connect(accounts[2]).unstakeAll()).wait()
    expect(await testToken.balanceOf(accounts[2].address)).to.equal(103)
  })
})
