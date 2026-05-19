const express = require('express')
const { greet } = require('./utils')

const app = express()
const PORT = process.env.PORT || 8080

app.get('/', (req, res) => {
  res.json({ message: greet('world'), service: 'node-app' })
})

app.get('/health', (req, res) => res.send('OK'))

app.listen(PORT, () => console.log(`listening on :${PORT}`))
