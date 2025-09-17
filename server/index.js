const express = require("express");
const mongoose = require("mongoose");
const bodyParser = require("body-parser");
const cors = require("cors");
const crypto = require("crypto");

const app = express();
app.use(bodyParser.json());
app.use(cors());

// Connect MongoDB (replace with your URI if using Atlas)
mongoose.connect("mongodb://127.0.0.1:27017/suraksha", {
    useNewUrlParser: true,
    useUnifiedTopology: true
}).then(() => console.log("MongoDB Connected"))
  .catch(err => console.log(err));

// User Schema
const userSchema = new mongoose.Schema({
    name: String,
    phone: String,
    digitalID: String
});
const User = mongoose.model("User", userSchema);

// Alert Schema
const alertSchema = new mongoose.Schema({
    userID: String,
    type: String, // "panic" | "geofence"
    location: {
        lat: Number,
        lng: Number
    },
    timestamp: { type: Date, default: Date.now },
    status: { type: String, default: "active" }
});
const Alert = mongoose.model("Alert", alertSchema);

// ✅ Register User
app.post("/api/register", async (req, res) => {
    const { name, phone } = req.body;
    const digitalID = crypto.randomBytes(8).toString("hex"); // Mock blockchain ID
    const newUser = new User({ name, phone, digitalID });
    await newUser.save();
    res.json({ success: true, digitalID });
});

// ✅ Panic/Geo-fence Alert
app.post("/api/alert", async (req, res) => {
    const { userID, type, location } = req.body;
    const newAlert = new Alert({ userID, type, location });
    await newAlert.save();
    res.json({ success: true, message: "Alert received" });
});

// ✅ Fetch Alerts (for Dashboard)
app.get("/api/alerts", async (req, res) => {
    const alerts = await Alert.find().sort({ timestamp: -1 });
    res.json(alerts);
});

// ✅ Root Check
app.get("/", (req, res) => {
    res.send("Suraksha Backend Running ✅");
});

app.listen(5000, () => console.log("Server running on http://localhost:5000"));
