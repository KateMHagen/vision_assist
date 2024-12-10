const functions = require("firebase-functions");
const axios = require("axios");

const GOOGLE_MAPS_API_KEY = "AIzaSyAbxrh2JQja5pH05lidjgq5ZHfDFW8ZiZM";

// Search location function
exports.searchLocation = functions.https.onRequest(async (req, res) => {
  const query = req.query.query;

  if (!query) {
    res.status(400).send("Query parameter is missing");
    return;
  }

  try {
    console.log("Searching for query:", query);  // Log the query being searched
    const response = await axios.get(
      `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${query}&key=${GOOGLE_MAPS_API_KEY}`,
    );
    console.log("Google Maps API response:", response.data);  // Log the response

    if (response.data.status === "OK") {
      res.json(response.data);  // Return the result in JSON format
    } else {
      res.status(500).send("Error from Google Maps API: " + response.data.status);
    }
  } catch (error) {
    console.error("Error fetching location data:", error.message);
    res.status(500).send("Internal Server Error");
  }
});
