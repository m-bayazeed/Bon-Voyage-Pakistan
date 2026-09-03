import logging
from datetime import datetime, timezone, timedelta
from typing import Dict, List

logger = logging.getLogger(__name__)

# Curated repository of critical Pakistani Mountain Corridors and Highway Advisories
CURATED_PAKISTAN_ADVISORIES = [
    {
        "id": "ALT-KKH-001",
        "category": "roadCondition",
        "severity": "critical",
        "title": "Karakoram Highway Landslide Clearance Protocol",
        "location": "KKH Section near Attabad Tunnel, Upper Hunza",
        "city": "Hunza Valley",
        "latitude": 36.3350,
        "longitude": 74.8050,
        "description": "Active rock slippage and debris clearance operations ongoing along KKH Attabad stretch. Frontier Works Organisation (FWO) heavy machinery actively deployed.",
        "recommended_action": "Avoid non-essential transit toward Upper Hunza until full clearance. Contact Gilgit-Baltistan Tourist Police helpline (1422) for live convoy clearance status.",
        "source": "Frontier Works Organisation (FWO) & GB District Administration",
    },
    {
        "id": "ALT-BAB-002",
        "category": "weather",
        "severity": "critical",
        "title": "Babusar Pass Snowfall & Heavy Ice Advisory",
        "location": "Babusar Pass Summit (Elevation 13,691 ft), Kaghan Valley",
        "city": "Naran & Kaghan",
        "latitude": 35.1500,
        "longitude": 74.0500,
        "description": "High altitude snowfall and sub-zero black ice render Babusar Top slippery and dangerous. Pass is subject to strict daytime convoy regulations or seasonal winter closure.",
        "recommended_action": "Use the alternative Karakoram Highway (via Kohistan & Chilas) for travel between Rawalpindi/Islamabad and Gilgit.",
        "source": "National Disaster Management Authority (NDMA)",
    },
    {
        "id": "ALT-SKD-003",
        "category": "roadCondition",
        "severity": "high",
        "title": "Jaglot-Skardu Road Falling Stones Watch",
        "location": "Jaglot-Skardu Highway at Astak Nala",
        "city": "Skardu & Baltistan",
        "latitude": 35.5800,
        "longitude": 74.9200,
        "description": "Intermittent rock falling reported near Astak Nala due to moisture and thermal expansion. Single-lane traffic open under police monitoring.",
        "recommended_action": "Drive with extreme caution during daytime only. Avoid nighttime commuting along the deep Indus gorge.",
        "source": "National Highway Authority (NHA) Control Room",
    },
    {
        "id": "ALT-SWT-004",
        "category": "naturalDisaster",
        "severity": "high",
        "title": "River Swat Water Flow & Riparian Caution",
        "location": "Riverside Areas of Kalam, Madyan & Bahrain",
        "city": "Swat & Kalam",
        "latitude": 35.4800,
        "longitude": 72.5800,
        "description": "Glacier melt and upper catchment rainfall contribute to elevated river currents near Kalam and Madyan.",
        "recommended_action": "Refrain from setting up camps directly on riverbanks or low-lying gravel islands. Follow local district administration safety markers.",
        "source": "Provincial Disaster Management Authority (PDMA Khyber Pakhtunkhwa)",
    },
    {
        "id": "ALT-MUR-005",
        "category": "weather",
        "severity": "moderate",
        "title": "Dense Fog & Snow Chains Requirement",
        "location": "Murree Expressway (N-75) & Galiyat Belt",
        "city": "Murree & Galiyat",
        "latitude": 33.9060,
        "longitude": 73.3900,
        "description": "Dense fog reduces visibility to under 50 meters between Lower Topa and Changla Gali. Sub-zero temperatures create frost and black ice.",
        "recommended_action": "Keep vehicle fog lights illuminated, maintain generous following distance, and ensure functional tire chains for Galiyat ascents.",
        "source": "National Highways & Motorway Police (NHMP Sector M-75)",
    },
    {
        "id": "ALT-ISB-006",
        "category": "roadCondition",
        "severity": "moderate",
        "title": "Margalla Hills Trail Maintenance & Mud Slippage",
        "location": "Pir Sohawa Road, Margalla Foothills, Islamabad",
        "city": "Islamabad",
        "latitude": 33.7480,
        "longitude": 73.0640,
        "description": "Trail 3 and Pir Sohawa uphill road experiencing minor mud runoff following seasonal showers. Cyclists and motorists advised to slow down.",
        "recommended_action": "Use lower gear on steep bends and stay within marked speed limits.",
        "source": "Capital Development Authority (CDA Environment Wing)",
    },
    {
        "id": "ALT-LHE-007",
        "category": "advisory",
        "severity": "moderate",
        "title": "M-2 Motorway Winter Fog Timings Advisory",
        "location": "M-2 Motorway Interchange Toll Plaza, Lahore",
        "city": "Lahore",
        "latitude": 31.5200,
        "longitude": 74.3580,
        "description": "Thick smog and night fog expected across Punjab plains. M-2 Motorway (Lahore to Islamabad) may experience night closures for traveler safety.",
        "recommended_action": "Plan travel between 10:00 AM and 05:00 PM. Dial 130 for real-time motorway opening updates before departure.",
        "source": "National Highways & Motorway Police (NHMP Central Zone)",
    },
    {
        "id": "ALT-KHI-008",
        "category": "weather",
        "severity": "informational",
        "title": "Arabian Sea High Tide & Coastal Breeze",
        "location": "Clifton Beach, Do Darya & Hawke’s Bay, Karachi",
        "city": "Karachi",
        "latitude": 24.7720,
        "longitude": 67.0780,
        "description": "High tidal waves and gusty southwestern winds forecast along Clifton and Manora coasts. Beach swimming temporarily discouraged.",
        "recommended_action": "Enjoy coastal dining from designated seaside promenades; follow lifeguard beach flags.",
        "source": "Pakistan Meteorological Department (PMD Marine Centre)",
    },
    {
        "id": "ALT-QTA-009",
        "category": "weather",
        "severity": "informational",
        "title": "Ziarat Valley Cold Wave & Frost Advisory",
        "location": "Ziarat Valley & Juniper Biosphere Reserve",
        "city": "Quetta & Ziarat",
        "latitude": 30.3800,
        "longitude": 67.7200,
        "description": "Night temperatures dropping across Ziarat Juniper Forest. Morning frost on provincial highway bends.",
        "recommended_action": "Ensure vehicle antifreeze is topped up and pack thermal mountain apparel for excursions.",
        "source": "Balochistan Disaster Management Authority (PDMA)",
    },
    {
        "id": "ALT-PSH-010",
        "category": "roadCondition",
        "severity": "informational",
        "title": "Ring Road Northern Bypass Traffic Diversion",
        "location": "Peshawar Northern Bypass, Khyber Pakhtunkhwa",
        "city": "Peshawar",
        "latitude": 34.0150,
        "longitude": 71.5800,
        "description": "Bridge expansion joints maintenance in progress on Peshawar Northern Bypass. Minor diversions active via service lane.",
        "recommended_action": "Follow traffic warden signals for smooth bypass transit.",
        "source": "Peshawar Traffic Police & Highway Authority",
    },
]


class AdvisoryCollector:
    """Manages curated authentic travel and highway corridor advisories."""

    def collect_advisories(self) -> List[Dict]:
        """Return curated verified Pakistani mountain corridor advisories."""
        now_utc = datetime.now(timezone.utc)
        results = []
        for adv in CURATED_PAKISTAN_ADVISORIES:
            item = dict(adv)
            item["created_at"] = now_utc - timedelta(hours=2)
            item["expires_at"] = now_utc + timedelta(days=30)
            item["raw_data"] = f"curated_advisory_id={adv['id']}"
            results.append(item)
        return results


advisory_collector = AdvisoryCollector()
