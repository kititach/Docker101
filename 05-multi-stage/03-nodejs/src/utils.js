function greet(name) {
  return `Hello, ${name}! (node ${process.version})`
}

module.exports = { greet }
