"""
Bon Voyage Pakistan - AI Tour Planning Service using Groq API
Includes strict destination-to-interest verification to prevent AI hallucination.
"""

import os
import re
import json
import uuid
from typing import Dict, Any, List, Optional, Tuple, Set
from dotenv import load_dotenv
from groq import Groq

load_dotenv()

# Get Groq API Key
GROQ_API_KEY = os.getenv("GROQ_API_KEY_TripPlan") or os.getenv("GROQ_API_KEY")
MODEL_NAME = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")
FALLBACK_MODEL_NAME = "qwen/qwen3.6-27b"

_groq_client = None

def get_groq_client() -> Optional[Groq]:
    global _groq_client
    if _groq_client is None:
        key = os.getenv("GROQ_API_KEY_TripPlan") or os.getenv("GROQ_API_KEY")
        if key:
            _groq_client = Groq(api_key=key)
    return _groq_client


# ──────────────────────────────────────────────
# Text Sanitization Utilities
# ──────────────────────────────────────────────

def sanitize_ai_text(text: str) -> str:
    """
    Sanitizes AI text output:
    1. Removes all <reason>, <thought>, <think>, and <scratchpad> blocks.
    2. Strips all markdown hashtags (#, ##, ###).
    3. Strips all asterisks (*, **, ***) and converts them to <b>, <i>, <u> or clean bullets (•).
    4. Ensures only <b>, <i>, <u> tags and standard unicode bullets are used for emphasis.
    """
    if not isinstance(text, str):
        return text

    # Remove reasoning/thought tags and contents
    text = re.sub(
        r"<(?:reason|thought|think|scratchpad)>[\s\S]*?</(?:reason|thought|think|scratchpad)>",
        "",
        text,
        flags=re.IGNORECASE,
    )
    text = re.sub(r"<(?:reason|thought|think|scratchpad)>", "", text, flags=re.IGNORECASE)
    text = re.sub(r"</(?:reason|thought|think|scratchpad)>", "", text, flags=re.IGNORECASE)

    # Convert markdown bullet lists starting with * or - to unicode bullet •
    text = re.sub(r"^\s*[\*\-]\s+", "• ", text, flags=re.MULTILINE)

    # Convert markdown bold **text** or ***text*** to <b>text</b>
    text = re.sub(r"\*{2,3}(.*?)\*{2,3}", r"<b>\1</b>", text)
    # Convert markdown italics *text* to <i>text</i>
    text = re.sub(r"\*(.*?)\*", r"<i>\1</i>", text)
    # Remove any remaining stray asterisks
    text = text.replace("*", "")

    # Convert markdown headers (### Header) to bold
    text = re.sub(r"^#{1,6}\s*(.+)$", r"<b>\1</b>", text, flags=re.MULTILINE)
    text = text.replace("#", "")

    return text.strip()


def sanitize_json_data(obj: Any) -> Any:
    """Recursively sanitize all string fields in a JSON object/list."""
    if isinstance(obj, str):
        return sanitize_ai_text(obj)
    elif isinstance(obj, list):
        return [sanitize_json_data(item) for item in obj]
    elif isinstance(obj, dict):
        return {k: sanitize_json_data(v) for k, v in obj.items()}
    return obj


# ──────────────────────────────────────────────
# Destination Knowledge Base & Attraction Database
# ──────────────────────────────────────────────

INTEREST_CATEGORY_MAPPING: Dict[str, str] = {
    "mountain": "mountains",
    "mountains": "mountains",
    "mountain adventure": "mountains",
    "mountain peaks": "mountains",
    "hiking": "hiking_trails",
    "hiking trails": "hiking_trails",
    "hiking/trails": "hiking_trails",
    "trekking": "hiking_trails",
    "trekking & camping": "hiking_trails",
    "camping": "hiking_trails",
    "trails": "hiking_trails",
    "history": "historical",
    "historical": "historical",
    "history & heritage": "historical",
    "heritage": "historical",
    "monuments": "historical",
    "forts": "historical",
    "architecture": "historical",
    "culture": "cultural",
    "cultural": "cultural",
    "cultural festivals": "cultural",
    "festivals": "cultural",
    "shrines": "cultural",
    "crafts": "cultural",
    "artisan": "cultural",
    "food": "food",
    "local cuisine & food": "food",
    "cuisine": "food",
    "culinary": "food",
    "street food": "food",
    "nature": "nature_lakes",
    "nature & lakes": "nature_lakes",
    "lakes": "nature_lakes",
    "rivers": "nature_lakes",
    "waterfalls": "nature_lakes",
    "valleys": "nature_lakes",
    "photography": "photography",
    "photography & stargazing": "photography",
    "stargazing": "photography",
    "luxury": "luxury_urban",
    "luxury & wellness": "luxury_urban",
    "wellness": "luxury_urban",
    "beach": "coastal_beach",
    "coastal": "coastal_beach",
    "coastal & beach": "coastal_beach",
    "islands": "coastal_beach",
    "desert": "desert_safari",
    "desert safari": "desert_safari"
}

DESTINATION_VERIFIED_DATA: Dict[str, Dict[str, Any]] = {
    "multan": {
        "display_name": "Multan (City of Saints)",
        "supported_categories": {"historical", "cultural", "food", "photography", "luxury_urban"},
        "unsupported_explanation": "Multan is located in the flat alluvial plains of southern Punjab and has no natural mountains, high alpine terrain, or hiking trails.",
        "suggested_interests": [
            "History & Heritage",
            "Sufi Architecture & Culture",
            "Traditional Crafts (Kashikari Blue Pottery)",
            "Local Cuisine & Food",
            "Photography & Monuments"
        ],
        "alternative_destinations": [
            "Hunza Valley",
            "Skardu & Deosai",
            "Swat & Kalam",
            "Margalla Hills (Islamabad)"
        ],
        "attractions": {
            "historical": [
                "Shrine of Shah Rukn-e-Alam (Iconic 14th-century octagonal dome)",
                "Shrine of Bahauddin Zakariya",
                "Multan Fort & Qasim Bagh",
                "Tomb of Shah Shams Tabrez",
                "Clock Tower Multan (Ghanta Ghar)",
                "Patrick Alexander Vans Agnew Monument",
                "Yadgar-e-Shuhada Monument"
            ],
            "cultural": [
                "Hussain Agahi Traditional Bazaar",
                "Institute of Blue Pottery Development (Kashikari Crafts)",
                "Camel skin lamp (Naqashi) artisan quarter",
                "Chaman Zar Askari Lake Park"
            ],
            "food": [
                "Authentic Multani Sohan Halwa (Hafiz Halwa & Rewari)",
                "Multani Chaunsa Mango Orchards & Farm Tours (Seasonal)",
                "Bohar Gate Famous Fried Fish",
                "Ghanta Ghar Gol Gappay & Dahi Bhallay",
                "Traditional Doli Roti & Multani Kheer"
            ],
            "photography": [
                "Shah Rukn-e-Alam blue glazed tile architecture at golden hour",
                "Bahauddin Zakariya terracotta facade",
                "Qasim Bagh elevated panorama over Old Multan"
            ],
            "luxury_urban": [
                "Boutique city hotels on Abdali Road & Gulgasht Colony",
                "Multan Golf Club & Cantt scenic green promenades"
            ]
        }
    },
    "lahore": {
        "display_name": "Lahore (Cultural Capital of Pakistan)",
        "supported_categories": {"historical", "cultural", "food", "photography", "luxury_urban"},
        "unsupported_explanation": "Lahore is an urban plains metropolis with vast Mughal monuments and food culture, but has no mountain peaks or mountain hiking trails.",
        "suggested_interests": [
            "History & Heritage",
            "Cultural Festivals & Arts",
            "Local Cuisine & Food",
            "Architecture & Photography",
            "Luxury & Wellness"
        ],
        "alternative_destinations": [
            "Swat & Kalam",
            "Hunza Valley",
            "Naran & Kaghan",
            "Margalla Hills (Islamabad)"
        ],
        "attractions": {
            "historical": [
                "UNESCO World Heritage Lahore Fort & Sheesh Mahal",
                "Grand Badshahi Mosque",
                "3-Tier Mughal Shalimar Gardens",
                "Tomb of Emperor Jahangir & Asif Khan",
                "Wazir Khan Mosque (Persian Frescoes)",
                "Shahi Hammam (Royal Bathhouse)",
                "Minar-e-Pakistan",
                "Lahore Museum (Gandhara Fasting Buddha)"
            ],
            "cultural": [
                "Walled City (Androon Lahore) & Delhi Gate",
                "Anarkali Artisan Bazaar",
                "Wagah Border Patriotic Flag Lowering Parade",
                "Alhamra Arts Council & National College of Arts",
                "Pak Tea House"
            ],
            "food": [
                "Fort Road Food Street overlooking Badshahi Mosque",
                "Gawalmandi Food Street & Lakshmi Chowk Tawa Chicken",
                "Old Anarkali Halwa Puri & Siri Paye",
                "Phikkay ki Jalebi & Bashir Dar-ul-Mahi Fried Fish",
                "Goga Naqeebia Murgh Chanay & Kasuri Falooda"
            ],
            "photography": [
                "Badshahi Mosque grand courtyard at dusk",
                "Wazir Khan Mosque intricate mosaic tilework",
                "Sheesh Mahal glass mirror reflections"
            ],
            "luxury_urban": [
                "MM Alam Road Fine Dining & Designer Boutiques in Gulberg",
                "Packages Mall & Emporium Luxury Retail Centers",
                "Pearl Continental & Nishat Luxury Stays"
            ]
        }
    },
    "karachi": {
        "display_name": "Karachi (City of Lights)",
        "supported_categories": {"coastal_beach", "historical", "cultural", "food", "luxury_urban", "photography"},
        "unsupported_explanation": "Karachi is a coastal Arabian Sea metropolis famous for beaches and food streets, but does not feature alpine mountain ranges or mountain trekking trails.",
        "suggested_interests": [
            "Coastal & Beach",
            "Local Cuisine & Food",
            "History & Heritage",
            "Cultural Festivals",
            "Luxury & Urban Wellness"
        ],
        "alternative_destinations": [
            "Gorakh Hill Station",
            "Hunza Valley",
            "Skardu & Deosai",
            "Swat & Kalam"
        ],
        "attractions": {
            "coastal_beach": [
                "Clifton Beach & Sea View Promenade",
                "Hawkesbay Beach & Sandspit Green Turtle Reserve",
                "French Beach & Turtle Beach",
                "Churna Island Scuba Diving & Snorkeling Excursion",
                "Manora Island & Historic Lighthouse"
            ],
            "historical": [
                "Mazar-e-Quaid (Mausoleum of Muhammad Ali Jinnah)",
                "Mohatta Palace Museum",
                "Frere Hall & Sadequain Murals",
                "National Museum of Pakistan",
                "Empress Market & Victoria Monument"
            ],
            "cultural": [
                "Port Grand Cultural & Food Village",
                "Arts Council of Pakistan",
                "Zainab Market Handloom & Leather Bazaars"
            ],
            "food": [
                "Burns Road Historic Food Street (Waheed Kebab & Delhi Rabri)",
                "Kolachi Seaside Restaurant at Do Darya",
                "Javed Nihari & Zahid Nihari",
                "Student Biryani & Karachi Seafood Platters"
            ],
            "photography": [
                "Arabian Sea sunset from Do Darya wooden deck",
                "Mohatta Palace illuminated pink stone facade",
                "Mazar-e-Quaid white marble reflections"
            ],
            "luxury_urban": [
                "Dolmen Mall Clifton Luxury Shopping",
                "Beach Luxury Hotel & Mövenpick Stays"
            ]
        }
    },
    "hunza": {
        "display_name": "Hunza Valley (Karakoram Mountains)",
        "supported_categories": {"mountains", "hiking_trails", "nature_lakes", "historical", "cultural", "food", "photography", "luxury_urban"},
        "unsupported_explanation": "Hunza is a high-altitude mountain paradise and has no coastal beaches.",
        "suggested_interests": [
            "Mountain Adventure",
            "Trekking & Camping",
            "Nature & Lakes",
            "History & Heritage",
            "Photography & Stargazing",
            "Local Cuisine & Food"
        ],
        "alternative_destinations": ["Gwadar & Makran", "Karachi"],
        "attractions": {
            "mountains": [
                "Rakaposhi Peak Viewpoint (7,788m)",
                "Ultar Sar & Ladyfinger Peak",
                "Passu Cathedral Cones (Tupopdan)",
                "Diran Peak & Shispar Peak Vista",
                "Khunjerab Pass (15,397 ft Pak-China Border)"
            ],
            "hiking_trails": [
                "Passu Glacier Hike",
                "Borith Lake to White Glacier Trail",
                "Rakaposhi Base Camp Trek (Minapin start)",
                "Ultar Meadow Trek from Karimabad",
                "Ondra Poygah Heritage Stairway Trek in Gulmit"
            ],
            "nature_lakes": [
                "Attabad Lake (Turquoise Waters & Jet Ski)",
                "Borith Lake (Migratory Bird Sanctuary)",
                "Khunjerab National Park (Snow Leopard & Ibex habitat)",
                "Shimshal Valley Riverbanks"
            ],
            "historical": [
                "700-year-old Baltit Fort",
                "900-year-old Altit Fort & Royal Gardens",
                "Ganish 1,000-year-old Historic Silk Road Settlement",
                "Sacred Rocks of Hunza (Petroglyphs)",
                "Hussaini Suspension Bridge"
            ],
            "cultural": [
                "Karimabad Handicrafts & Gemstone Bazaar",
                "Traditional Hunza Music & Carpet Weaving Centers in Gulmit",
                "Apricot Blossom Festival (Spring) & Autumn Foliage"
            ],
            "food": [
                "Authentic Hunza Chapshuro (Meat Stuffed Flatbread)",
                "Famous Hunza Walnut Cake at Karimabad Cafes",
                "Organic Mamtu Dumplings & Gyaling with Apricot Honey",
                "Yak Steak & Fresh Apricot Kernel Oil Dishes"
            ],
            "photography": [
                "Duikar (Eagle's Nest) 360-degree sunrise/sunset panorama",
                "Passu Cones mirror reflection in Karakoram highway puddles",
                "Milky Way astrophotography over Attabad Lake"
            ]
        }
    },
    "skardu": {
        "display_name": "Skardu & Deosai (Land of Giants)",
        "supported_categories": {"mountains", "hiking_trails", "nature_lakes", "historical", "cultural", "food", "photography", "luxury_urban"},
        "unsupported_explanation": "Skardu is an alpine valley in Baltistan surrounded by 8000m peaks and has no coastal beaches.",
        "suggested_interests": [
            "Mountain Adventure",
            "Trekking & Camping",
            "Nature & Lakes",
            "History & Heritage",
            "Photography & Stargazing",
            "Local Cuisine & Food"
        ],
        "alternative_destinations": ["Gwadar & Makran", "Karachi"],
        "attractions": {
            "mountains": [
                "K2 & Broad Peak Vistas from Upper Passes",
                "Katpana High-Altitude Cold Desert Dunes against Snow Peaks",
                "Sarfaranga Cold Desert",
                "Mashabrum & Gasherbrum Panorama"
            ],
            "hiking_trails": [
                "Marsur Rock Hike (Pride Rock of Baltistan)",
                "Kharpocho Fort Elevation Trail",
                "Sheosar Lake Plateau Nature Hike in Deosai",
                "Basho Valley Alpine Forest Trek",
                "K2 Base Camp Trek Gateway Route"
            ],
            "nature_lakes": [
                "Deosai National Park & Plains (13,500 ft Land of Giants)",
                "Sheosar Lake (Heart-shaped high-altitude lake)",
                "Shangrila Resort Lake (Lower Kachura)",
                "Upper Kachura Lake (Boating & Trout Fish)",
                "Sadpara Lake & Dam",
                "Manthokha Waterfall & Khamosh Waterfall",
                "Blind Lake Shigar"
            ],
            "historical": [
                "400-year-old Shigar Fort (Fong-Khar Palace)",
                "Khaplu Palace & Royal Heritage Museum",
                "Kharpocho Fort (King of Forts overlooking Indus)",
                "Manthal 8th-century Buddha Rock Carvings",
                "Chaqchan Mosque (700-year-old Wooden Mosque)"
            ],
            "cultural": [
                "Skardu Old Bazaar & Gemstone Market",
                "Traditional Balti Handicraft & Wood Carving Guilds",
                "Polo Matches at Shigar Ground"
            ],
            "food": [
                "Authentic Balti Gosht cooked in traditional stone pots (Deygh)",
                "Fresh Pan-Fried Kachura Trout Fish",
                "Balti Mamtu & Marzan Dumplings",
                "Apricot Kernels & Sea Buckthorn Herbal Tea"
            ],
            "photography": [
                "Deosai Plains golden wildflowers & Himalayan Brown Bear",
                "Katpana Desert sand ripples meeting snowclad mountains",
                "Shangrila Pagoda reflections in emerald waters"
            ]
        }
    },
    "swat": {
        "display_name": "Swat & Kalam (Switzerland of the East)",
        "supported_categories": {"mountains", "hiking_trails", "nature_lakes", "historical", "cultural", "food", "photography"},
        "unsupported_explanation": "Swat Valley is an alpine pine forest and river valley with no coastal sea beaches.",
        "suggested_interests": [
            "Nature & Lakes",
            "Mountain Adventure",
            "Trekking & Camping",
            "History & Heritage",
            "Local Cuisine & Food",
            "Photography & Stargazing"
        ],
        "alternative_destinations": ["Gwadar & Makran", "Karachi"],
        "attractions": {
            "mountains": [
                "Malam Jabba Ski Resort & Chairlift Peak",
                "Spin Khwar Peak & Falak Sar backdrop",
                "Gabin Jabba Alpine Ridges"
            ],
            "hiking_trails": [
                "Mahodand Lake to Saifullah Lake Trek",
                "Kundol Lake Alpine Trek (Ladu start)",
                "Ushu Pine Forest Walking Trails",
                "Malam Jabba Forest & Ridge Hiking Trail",
                "Izmis Lake Wilderness Trek"
            ],
            "nature_lakes": [
                "Mahodand Lake (Lake of Fishes in Upper Kalam)",
                "Saifullah Lake & Nasirullah Lake",
                "Kundol Lake",
                "Swat River Fizagat Cascades",
                "White Palace Marghazar Water Springs",
                "Jarogo Waterfall (Highest in Swat)"
            ],
            "historical": [
                "Butkara I Buddhist Stupa (Ancient Gandhara Center)",
                "Swat Museum (Gandhara Buddhist Sculptures & Art)",
                "White Palace Marghazar (Built from Royal Marble in 1940)",
                "Shingardar Stupa & Ghalegay Buddhist Rock Carvings"
            ],
            "cultural": [
                "Mingora Gemstone & Emerald Bazaar",
                "Swati Woolen Shawls & Hand-Embroidered Fabric Markets",
                "Kalam Wood Carving Artisan Shops"
            ],
            "food": [
                "Pan-Fried Swat River Trout with Spicy Lemon Walnut Chutney",
                "Peshawari-Swati Chapli Kebabs",
                "Wild Berry Swat Honey & Fresh Farm Apples",
                "Traditional Charsi Tikka & Dum Pukht"
            ],
            "photography": [
                "Malam Jabba chairlift ride over mist-covered pine valleys",
                "Mahodand Lake colorful wooden boats with mountain backdrop",
                "Autumn gold in Ushu dense pine forest"
            ]
        }
    },
    "naran": {
        "display_name": "Naran & Kaghan Valley",
        "supported_categories": {"mountains", "hiking_trails", "nature_lakes", "photography", "food"},
        "unsupported_explanation": "Naran is a high-altitude Himalayan valley with no urban monuments or coastal beaches.",
        "suggested_interests": [
            "Nature & Lakes",
            "Mountain Adventure",
            "Trekking & Camping",
            "Photography & Stargazing",
            "Local Cuisine & Food"
        ],
        "alternative_destinations": ["Lahore Heritage", "Multan", "Karachi"],
        "attractions": {
            "mountains": [
                "Babusar Top (13,691 ft Pass connecting KPK to Gilgit)",
                "Malika Parbat (5,290m Queen of Mountains)",
                "Makra Peak (Shogran Viewpoint)"
            ],
            "hiking_trails": [
                "Ansoo Lake (Tear-shaped lake) High Altitude Trek",
                "Siri Paye Meadows Ridge Hike",
                "Lalazar Plateau Alpine Forest Trek",
                "Dudipatsar Lake (Queen of Lakes) Wilderness Trek"
            ],
            "nature_lakes": [
                "Saif-ul-Malook Lake (Fabled Emerald Alpine Lake)",
                "Lulusar Lake (Reflective Lake at Babusar base)",
                "Dudipatsar Lake & Pyala Lake",
                "Kunhar River Rafting Stretches",
                "Siri Paye Meadows & Shogran Plateau"
            ],
            "food": [
                "Fresh River Trout at Kunhar Riverbank Dhabas",
                "Hot Shinwari Karahi & Tandoori Naan in Naran Bazaar",
                "Hot Cardamom Chai overlooking Saif-ul-Malook"
            ],
            "photography": [
                "Saif-ul-Malook crystal reflections of Malika Parbat",
                "Babusar Top cloud inversion and winding Karakoram hairpin bends",
                "Siri Paye horse pastures in summer fog"
            ]
        }
    },
    "fairy meadows": {
        "display_name": "Fairy Meadows & Nanga Parbat",
        "supported_categories": {"mountains", "hiking_trails", "nature_lakes", "photography", "camping"},
        "unsupported_explanation": "Fairy Meadows is a rugged wilderness basecamp under Nanga Parbat and has no urban malls, historical forts, or beaches.",
        "suggested_interests": [
            "Mountain Adventure",
            "Trekking & Camping",
            "Photography & Stargazing",
            "Nature & Lakes"
        ],
        "alternative_destinations": ["Lahore Heritage", "Multan", "Karachi"],
        "attractions": {
            "mountains": [
                "Nanga Parbat (8,126m Killer Mountain / Raikot Face)",
                "Chongra Peak & Raikot Glacier Ridge",
                "Fairy Meadows Lush Alpine Plateau"
            ],
            "hiking_trails": [
                "Beyal Camp Forest Trek",
                "Nanga Parbat Base Camp Trek (German Viewpoint)",
                "Raikot Glacier Traverse Hike",
                "Tattu Village to Fairy Meadows Steep Jeep & Mule Trail"
            ],
            "nature_lakes": [
                "Fairy Meadows Reflection Lake (Mirrors Nanga Parbat)",
                "Raikot Glacial Streams and Pine Woodlands"
            ],
            "photography": [
                "Milky Way Galaxy and meteor showers directly over Nanga Parbat summit",
                "Wooden log cabins glowing under moonlight",
                "Reflection Lake morning mirror shot"
            ]
        }
    },
    "neelum": {
        "display_name": "Neelum Valley (Azad Kashmir)",
        "supported_categories": {"mountains", "hiking_trails", "nature_lakes", "historical", "photography", "cultural"},
        "unsupported_explanation": "Neelum Valley is an alpine river valley and has no coastal sea beaches.",
        "suggested_interests": [
            "Nature & Lakes",
            "Mountain Adventure",
            "Trekking & Camping",
            "Photography & Stargazing",
            "History & Heritage"
        ],
        "alternative_destinations": ["Gwadar & Makran", "Karachi"],
        "attractions": {
            "mountains": [
                "Arang Kel Alpine Plateau (Pearl of Neelum)",
                "Baboon Valley Mountain Ridges",
                "Chitta Katha Peak"
            ],
            "hiking_trails": [
                "Ratti Gali Lake Alpine Trek (Dowarian start)",
                "Kel to Arang Kel Chairlift & Forest Hike",
                "Chitta Katha Lake Wilderness Trek (Sharda start)",
                "Taobat Border Wilderness Walking Trail"
            ],
            "nature_lakes": [
                "Ratti Gali Lake (Glacial Red Alpine Lake at 12,130 ft)",
                "Kutton Waterfall (Jagran Valley)",
                "Dhani Waterfall",
                "Neelum Riverbank Promenades at Keran (LOC View)",
                "Taobat Valley (Last settlement of Neelum)"
            ],
            "historical": [
                "Sharda Peeth Ancient 6th-Century University & Temple Ruins",
                "Kishan Ghati Historic Caves"
            ],
            "photography": [
                "Ratti Gali Lake red flower meadows under towering ice walls",
                "Arang Kel green wooden village houses overlooking misty peaks",
                "Kutton waterfall foaming white cascades"
            ]
        }
    },
    "gwadar": {
        "display_name": "Gwadar & Makran Coastal Highway",
        "supported_categories": {"coastal_beach", "nature_lakes", "historical", "food", "photography"},
        "unsupported_explanation": "Gwadar is an arid coastal peninsula along the Arabian Sea and does not feature snow-capped alpine mountains or pine forest hiking trails.",
        "suggested_interests": [
            "Coastal & Beach",
            "Photography & Stargazing",
            "Local Cuisine & Food",
            "History & Heritage"
        ],
        "alternative_destinations": ["Hunza Valley", "Swat & Kalam", "Skardu & Deosai"],
        "attractions": {
            "coastal_beach": [
                "Hammerhead Rock (Koh-e-Batil)",
                "Kund Malir Golden Beach & Azure Waves",
                "Ormara Beach (Turtle Breeding Grounds)",
                "Astola Island (Island of the Seven Hills - Scuba & Coral Reefs)",
                "Gwadar Marine Drive & Sunset Point"
            ],
            "nature_lakes": [
                "Princess of Hope Natural Rock Formation",
                "Sphinx of Balochistan",
                "Hingol National Park (Mud Volcanoes & Desert Canyons)",
                "Buzi Pass & Makran Mud Volcanoes (Chandragup)"
            ],
            "historical": [
                "Hinglaj Mata Ancient Temple in Hingol Gorge",
                "Historic Omani Fort Ruins in Old Gwadar Town",
                "Old Gwadar Fish Harbor (Century-old wooden boat building)"
            ],
            "food": [
                "Balochi Sajji cooked over open wood coals",
                "Fresh Grilled Lobster, Jumbo Prawns, and Red Snapper",
                "Traditional Balochi Kaak (Stone Bread) & Kahwa"
            ],
            "photography": [
                "Hammerhead Rock cliff drop into the deep blue Arabian Sea",
                "Princess of Hope standing against starlit night skies",
                "Kund Malir golden dunes meeting ocean waves"
            ]
        }
    },
    "islamabad": {
        "display_name": "Islamabad & Margalla Hills",
        "supported_categories": {"hiking_trails", "nature_lakes", "historical", "cultural", "food", "luxury_urban", "photography"},
        "unsupported_explanation": "Islamabad features green Margalla hiking trails and urban monuments, but has no high-altitude 8000m glacial alpine mountains or coastal beaches.",
        "suggested_interests": [
            "Hiking & Nature Trails",
            "History & Heritage",
            "Local Cuisine & Food",
            "Culture & Museums",
            "Luxury & Urban Wellness"
        ],
        "alternative_destinations": ["Hunza Valley", "Skardu & Deosai", "Gwadar & Makran"],
        "attractions": {
            "hiking_trails": [
                "Margalla Hills Trail 3 (Scenic Ridge Hike)",
                "Margalla Hills Trail 5 (Streams & Pine Woodland)",
                "Trail 6 to Talhar Ridge",
                "Daman-e-Koh to Pir Sohawa Nature Trail"
            ],
            "nature_lakes": [
                "Rawal Lake & Lake View Park",
                "Daman-e-Koh Elevated Viewpoint",
                "Pir Sohawa (Monal Panoramic Viewpoint at 3,600 ft)",
                "Shah Allah Ditta Ancient Caves & Natural Spring"
            ],
            "historical": [
                "Grand Faisal Mosque (Modern Islamic Architecture)",
                "Pakistan Monument & National History Museum",
                "Saidpur 500-year-old Mughal & Hindu Heritage Village",
                "Lok Virsa Folk Heritage Museum",
                "Golra Sharif Railway Heritage Museum"
            ],
            "food": [
                "Monal & La Montana Dining on Margalla Heights",
                "Saidpur Village Traditional Desi Dhabas",
                "F-7 / Beverly Center Artisan Cafes & Karahi Points"
            ],
            "photography": [
                "Faisal Mosque illuminated beneath Margalla Hills backdrop",
                "Pakistan Monument petal structures at twilight",
                "Rawal Lake sunset reflections"
            ]
        }
    }
}


def find_destination_entry(destination: str) -> Optional[Dict[str, Any]]:
    """Match a user-provided destination string to a verified database entry."""
    dest_clean = destination.lower().strip()

    # Exact key match
    if dest_clean in DESTINATION_VERIFIED_DATA:
        return DESTINATION_VERIFIED_DATA[dest_clean]

    # Partial/alias match
    for key, data in DESTINATION_VERIFIED_DATA.items():
        if key in dest_clean or dest_clean in key:
            return data
        if "hunza" in dest_clean or "gilgit" in dest_clean or "karimabad" in dest_clean:
            return DESTINATION_VERIFIED_DATA["hunza"]
        if "skardu" in dest_clean or "deosai" in dest_clean or "shigar" in dest_clean or "baltistan" in dest_clean:
            return DESTINATION_VERIFIED_DATA["skardu"]
        if "swat" in dest_clean or "kalam" in dest_clean or "mingora" in dest_clean or "malam jabba" in dest_clean:
            return DESTINATION_VERIFIED_DATA["swat"]
        if "naran" in dest_clean or "kaghan" in dest_clean or "shogran" in dest_clean or "saif-ul-malook" in dest_clean:
            return DESTINATION_VERIFIED_DATA["naran"]
        if "fairy" in dest_clean or "nanga parbat" in dest_clean:
            return DESTINATION_VERIFIED_DATA["fairy meadows"]
        if "neelum" in dest_clean or "kashmir" in dest_clean or "ratti gali" in dest_clean:
            return DESTINATION_VERIFIED_DATA["neelum"]
        if "gwadar" in dest_clean or "makran" in dest_clean or "kund malir" in dest_clean or "ormara" in dest_clean:
            return DESTINATION_VERIFIED_DATA["gwadar"]
        if "lahore" in dest_clean:
            return DESTINATION_VERIFIED_DATA["lahore"]
        if "multan" in dest_clean:
            return DESTINATION_VERIFIED_DATA["multan"]
        if "karachi" in dest_clean:
            return DESTINATION_VERIFIED_DATA["karachi"]
        if "islamabad" in dest_clean or "rawalpindi" in dest_clean or "margalla" in dest_clean:
            return DESTINATION_VERIFIED_DATA["islamabad"]

    return None


def validate_destination_interests(destination: str, interests: List[str]) -> Dict[str, Any]:
    """
    Validates user's selected interests against verified attraction database for the chosen destination.
    Returns validation status, supported interests, unsupported interests, and verified attraction pool.
    """
    dest_entry = find_destination_entry(destination)
    if not dest_entry:
        # If destination is unknown/custom, allow standard generation with strict verification
        return {
            "is_valid": True,
            "incompatible": False,
            "destination_display": destination,
            "supported_interests": interests,
            "unsupported_interests": [],
            "verified_attractions": [],
            "suggested_interests": [],
            "alternative_destinations": ["Hunza Valley", "Skardu & Deosai", "Swat & Kalam", "Lahore Heritage", "Multan"]
        }

    supported_categories = dest_entry["supported_categories"]
    supported_interests: List[str] = []
    unsupported_interests: List[str] = []
    verified_attractions: List[str] = []

    for interest in interests:
        norm_key = interest.lower().strip()
        category = INTEREST_CATEGORY_MAPPING.get(norm_key, None)
        
        if not category:
            # Check for substring match in mapping
            for key, cat in INTEREST_CATEGORY_MAPPING.items():
                if key in norm_key:
                    category = cat
                    break

        if category and category in supported_categories:
            supported_interests.append(interest)
            if category in dest_entry.get("attractions", {}):
                verified_attractions.extend(dest_entry["attractions"][category])
        else:
            unsupported_interests.append(interest)

    # If all selected interests are unsupported:
    if len(supported_interests) == 0 and len(interests) > 0:
        unsupported_str = " or ".join([f"<b>{i}</b>" for i in unsupported_interests])
        suggested_ints = dest_entry.get("suggested_interests", ["History & Heritage", "Local Cuisine & Food"])
        suggested_dests = dest_entry.get("alternative_destinations", ["Hunza Valley", "Skardu & Deosai", "Swat & Kalam"])

        message = (
            f"<b>{dest_entry['display_name']}</b> does not currently have verified {unsupported_str} attractions matching your selected interests.\n\n"
            f"{dest_entry.get('unsupported_explanation', '')}\n\n"
            f"The destination is better suited to: <b>{' • '.join(suggested_ints)}</b>.\n\n"
            f"Please adjust your interests or choose another destination such as <b>{'</b>, <b>'.join(suggested_dests)}</b>."
        )

        return {
            "is_valid": False,
            "incompatible": True,
            "destination_display": dest_entry["display_name"],
            "supported_interests": [],
            "unsupported_interests": unsupported_interests,
            "verified_attractions": [],
            "suggested_interests": suggested_ints,
            "alternative_destinations": suggested_dests,
            "message": sanitize_ai_text(message)
        }

    # If at least some interests are supported:
    return {
        "is_valid": True,
        "incompatible": False,
        "destination_display": dest_entry["display_name"],
        "supported_interests": supported_interests,
        "unsupported_interests": unsupported_interests,
        "verified_attractions": verified_attractions,
        "suggested_interests": dest_entry.get("suggested_interests", []),
        "alternative_destinations": dest_entry.get("alternative_destinations", []),
        "unsupported_explanation": dest_entry.get("unsupported_explanation", "")
    }


# ──────────────────────────────────────────────
# Route Corridors & En-Route Transit Knowledge
# ──────────────────────────────────────────────

ROUTE_CORRIDORS: Dict[Tuple[str, str], Dict[str, Any]] = {
    ("islamabad", "lahore"): {
        "corridor_name": "M-2 Motorway / Grand Trunk Road Corridor",
        "allowed_enroute_stops": [
            "Kallar Kahar Lake & Salt Range Viewpoint",
            "Katas Raj Ancient Hindu Temples",
            "Khewra Salt Mine (World's 2nd Largest)",
            "Bhera Historic Interchange (Famous Dhaba Kheer & Sweets)",
            "Hiran Minar (Mughal Water Pavilion in Sheikhupura)"
        ],
        "strictly_forbidden_offroute": [
            "murree", "pindi point", "patriata", "ayubia", "khanpur", "khanpur dam",
            "nathia gali", "galyat", "malam jabba", "swat", "kalam", "naran",
            "kaghan", "hunza", "skardu", "multan", "faisalabad", "peshawar", "gwadar"
        ]
    },
    ("rawalpindi", "lahore"): {
        "corridor_name": "M-2 Motorway / Grand Trunk Road Corridor",
        "allowed_enroute_stops": [
            "Kallar Kahar Lake & Salt Range Viewpoint",
            "Katas Raj Ancient Hindu Temples",
            "Khewra Salt Mine (World's 2nd Largest)",
            "Bhera Historic Interchange (Famous Dhaba Kheer & Sweets)",
            "Hiran Minar (Mughal Water Pavilion in Sheikhupura)"
        ],
        "strictly_forbidden_offroute": [
            "murree", "pindi point", "patriata", "ayubia", "khanpur", "khanpur dam",
            "nathia gali", "galyat", "malam jabba", "swat", "kalam", "naran",
            "kaghan", "hunza", "skardu", "multan", "faisalabad", "peshawar", "gwadar"
        ]
    },
    ("lahore", "islamabad"): {
        "corridor_name": "M-2 Motorway / Grand Trunk Road Corridor",
        "allowed_enroute_stops": [
            "Hiran Minar (Sheikhupura)",
            "Bhera Service Interchange",
            "Kallar Kahar Lake & Salt Range Viewpoint",
            "Katas Raj Temples",
            "Khewra Salt Mine"
        ],
        "strictly_forbidden_offroute": [
            "murree", "pindi point", "patriata", "ayubia", "khanpur", "khanpur dam",
            "multan", "bahawalpur", "karachi", "swat", "naran", "hunza"
        ]
    },
    ("islamabad", "multan"): {
        "corridor_name": "M-2 / M-4 Motorway Corridor",
        "allowed_enroute_stops": [
            "Kallar Kahar Lake",
            "Pindi Bhattian Interchange",
            "Faisalabad Clock Tower & Eight Bazaars",
            "Harappa Archaeological Site & Museum (Sahiwal)"
        ],
        "strictly_forbidden_offroute": [
            "murree", "pindi point", "patriata", "ayubia", "khanpur", "swat",
            "naran", "hunza", "skardu", "karachi", "gwadar"
        ]
    },
    ("rawalpindi", "multan"): {
        "corridor_name": "M-2 / M-4 Motorway Corridor",
        "allowed_enroute_stops": [
            "Kallar Kahar Lake",
            "Pindi Bhattian Interchange",
            "Faisalabad Clock Tower & Eight Bazaars"
        ],
        "strictly_forbidden_offroute": [
            "murree", "pindi point", "patriata", "ayubia", "khanpur", "swat",
            "naran", "hunza", "skardu", "karachi", "gwadar"
        ]
    },
    ("islamabad", "swat"): {
        "corridor_name": "M-1 & Swat Motorway (M-16)",
        "allowed_enroute_stops": [
            "Takht-i-Bahi UNESCO Buddhist Monastery (Mardan)",
            "Malakand Pass (Dargai)",
            "Batkhela Bazaar & Swat Canal",
            "Chakdara Churchill Picket"
        ],
        "strictly_forbidden_offroute": [
            "murree", "pindi point", "patriata", "ayubia", "naran", "kaghan",
            "lahore", "multan", "hunza", "skardu", "karachi"
        ]
    },
    ("islamabad", "hunza"): {
        "corridor_name": "Hazara Motorway (M-15) & Karakoram Highway (N-35)",
        "allowed_enroute_stops": [
            "Taxila Museum (En-route stop)",
            "Abbottabad Shimla Hill Viewpoint",
            "Mansehra Ashoka Rock Edicts",
            "Besham Indus Viewpoint",
            "Chilas Ancient Rock Carvings",
            "3 Mountain Ranges Junction (Himalaya, Karakoram, Hindu Kush)",
            "Rakaposhi Viewpoint (Ghizer / Nagar)"
        ],
        "strictly_forbidden_offroute": [
            "lahore", "multan", "karachi", "swat", "gwadar", "murree"
        ]
    },
    ("islamabad", "skardu"): {
        "corridor_name": "Hazara Motorway & KKH & Jaglot-Skardu Road",
        "allowed_enroute_stops": [
            "Abbottabad",
            "Besham Indus River Viewpoint",
            "Chilas",
            "3 Mountain Ranges Junction",
            "Jaglot Indus-Gilgit River Confluence",
            "Roundu Indus Gorge"
        ],
        "strictly_forbidden_offroute": [
            "lahore", "multan", "karachi", "swat", "gwadar", "murree"
        ]
    },
    ("islamabad", "naran"): {
        "corridor_name": "Hazara Motorway (M-15) & N-15 Highway",
        "allowed_enroute_stops": [
            "Abbottabad",
            "Mansehra",
            "Balakot (Gateway to Kaghan)",
            "Kawai Waterfall",
            "Paras Pine Forest"
        ],
        "strictly_forbidden_offroute": [
            "murree", "lahore", "multan", "swat", "hunza", "skardu"
        ]
    },
    ("karachi", "gwadar"): {
        "corridor_name": "Makran Coastal Highway (N-10)",
        "allowed_enroute_stops": [
            "Hub & Zero Point (Uthal)",
            "Kund Malir Golden Beach",
            "Hingol National Park (Princess of Hope, Sphinx of Balochistan)",
            "Buzi Pass Golden Canyons",
            "Ormara Coastal Vista"
        ],
        "strictly_forbidden_offroute": [
            "lahore", "islamabad", "multan", "swat", "hunza", "skardu", "sukkur", "hyderabad"
        ]
    }
}


def get_route_corridor_rules(departing: str, destination: str) -> Tuple[List[str], Set[str]]:
    """Returns allowed enroute stops and strictly forbidden offroute place keywords."""
    dep_norm = departing.lower()
    dest_norm = destination.lower()

    for (d_dep, d_dest), rules in ROUTE_CORRIDORS.items():
        if (d_dep in dep_norm or dep_norm in d_dep) and (d_dest in dest_norm or dest_norm in d_dest):
            return rules.get("allowed_enroute_stops", []), set(rules.get("strictly_forbidden_offroute", []))

    # General default forbidden check:
    forbidden: Set[str] = set()
    if any(k in dest_norm for k in ["lahore", "multan", "bahawalpur", "karachi"]):
        forbidden.update([
            "murree", "pindi point", "patriata", "ayubia", "khanpur", "khanpur dam",
            "nathia gali", "galyat", "swat", "kalam", "naran", "hunza", "skardu"
        ])

    return [], forbidden


def normalize_attraction_key(name: str) -> str:
    """Normalizes an attraction string into a canonical key for duplicate detection."""
    if not isinstance(name, str):
        return ""
    text = name.lower()
    text = re.sub(r"[^\w\s]", " ", text)
    
    # Specific known canonical mappings
    if "badshahi" in text:
        return "badshahi_mosque"
    if "lahore fort" in text or "shahi qila" in text or "sheesh mahal" in text:
        return "lahore_fort"
    if "shalimar" in text:
        return "shalimar_gardens"
    if "shahi hammam" in text or "royal bath" in text:
        return "shahi_hammam"
    if "wazir khan" in text:
        return "wazir_khan_mosque"
    if "wagah" in text:
        return "wagah_border"
    if "jahangir" in text and "tomb" in text:
        return "jahangir_tomb"
    if "minar e pakistan" in text or "minar-e-pakistan" in text:
        return "minar_e_pakistan"
    if "lahore museum" in text:
        return "lahore_museum"
    if "rukn e alam" in text or "rukn-e-alam" in text:
        return "shah_rukn_e_alam"
    if "bahauddin zakariya" in text:
        return "bahauddin_zakariya"
    if "multan fort" in text or "qasim bagh" in text:
        return "multan_fort"
    if "shams tabrez" in text:
        return "shah_shams_tabrez"
    if "clock tower" in text or "ghanta ghar" in text:
        return "clock_tower"
    if "blue pottery" in text or "kashikari" in text:
        return "blue_pottery_institute"
    if "baltit" in text:
        return "baltit_fort"
    if "altit" in text:
        return "altit_fort"
    if "attabad" in text:
        return "attabad_lake"
    if "hussaini" in text:
        return "hussaini_bridge"
    if "passu" in text and ("cone" in text or "tupopdan" in text):
        return "passu_cones"
    if "eagle" in text and "nest" in text:
        return "duikar_eagles_nest"
    if "rakaposhi" in text:
        return "rakaposhi_viewpoint"
    if "shangrila" in text or "lower kachura" in text:
        return "shangrila_kachura"
    if "upper kachura" in text:
        return "upper_kachura_lake"
    if "deosai" in text or "sheosar" in text:
        return "deosai_national_park"
    if "shigar fort" in text or "fong khar" in text:
        return "shigar_fort"
    if "khaplu" in text:
        return "khaplu_palace"
    if "malam jabba" in text:
        return "malam_jabba"
    if "mahodand" in text:
        return "mahodand_lake"
    if "saif ul malook" in text or "saiful malook" in text:
        return "saif_ul_malook"
    if "faisal mosque" in text:
        return "faisal_mosque"
    if "daman e koh" in text or "daman-e-koh" in text:
        return "daman_e_koh"
    if "monal" in text or "pir sohawa" in text:
        return "pir_sohawa_monal"
    if "trail 3" in text or "trail 5" in text:
        return "margalla_hiking_trail"
    if "pakistan monument" in text:
        return "pakistan_monument"
    if "khewra" in text:
        return "khewra_salt_mine"
    if "kallar kahar" in text:
        return "kallar_kahar_lake"
    if "katas raj" in text:
        return "katas_raj_temples"
    if "hiran minar" in text:
        return "hiran_minar"

    fillers = [
        "unesco world heritage", "unesco", "ancient", "historic", "historical", "grand",
        "visit to", "exploration of", "guided tour", "famous", "iconic", "viewpoint",
        "the", "overlooking", "at", "in", "and", "of", "shrine", "tomb", "masjid",
        "mosque", "lake", "fort", "bazaar", "palace", "park", "gardens", "garden"
    ]
    words = [w for w in text.split() if w not in fillers and len(w) > 2]
    return "_".join(sorted(words)) if words else text.strip().replace(" ", "_")


def validate_and_deduplicate_itinerary(
    days_plan: List[Dict[str, Any]],
    departing: str,
    destination: str,
    verified_pool: List[str]
) -> List[Dict[str, Any]]:
    """
    Post-generation validator & auto-corrector:
    1. Removes any off-route attraction (e.g. Murree on an Islamabad -> Lahore trip).
    2. Enforces that each attraction appears strictly ONCE across the entire itinerary.
    3. Replaces duplicates and off-route places with unused verified attractions from the pool.
    4. If pool is exhausted, fills with authentic local cultural/culinary/leisure experiences.
    5. Cleans route strings to ensure no off-route places are mentioned.
    """
    _, forbidden_keywords = get_route_corridor_rules(departing, destination)
    seen_canonical_keys: Set[str] = set()

    # Track unused verified attractions
    available_verified: List[str] = []
    for attr in verified_pool:
        k = normalize_attraction_key(attr)
        if not any(fb in attr.lower() for fb in forbidden_keywords):
            available_verified.append(attr)

    backup_activities = [
        "Leisure culinary walking tour & local street specialty sampling",
        "Artisan craft quarter exploration & traditional souvenir shopping",
        "Scenic sunset tea & photography rest stop",
        "Relaxed evening stroll through traditional bazaar",
        "Comfortable dining & peaceful evening rest at hotel"
    ]
    backup_index = 0

    corrected_days: List[Dict[str, Any]] = []

    for day in days_plan:
        day_num = day.get("dayNumber", len(corrected_days) + 1)
        raw_attractions = day.get("attractions", [])
        cleaned_attractions: List[str] = []

        for raw_attr in raw_attractions:
            attr_lower = raw_attr.lower()

            # Check 1: Is this off-route?
            is_offroute = any(fb in attr_lower for fb in forbidden_keywords)
            if is_offroute:
                continue

            # Check 2: Has this attraction key already been seen on a previous day?
            c_key = normalize_attraction_key(raw_attr)
            if c_key in seen_canonical_keys:
                continue

            # Valid and unique
            seen_canonical_keys.add(c_key)
            cleaned_attractions.append(raw_attr)

        # If day has fewer than 2 attractions due to off-route / duplicate rejection, fill from unused verified pool
        while len(cleaned_attractions) < 2:
            replacement = None
            for cand in available_verified:
                cand_key = normalize_attraction_key(cand)
                if cand_key not in seen_canonical_keys:
                    replacement = cand
                    seen_canonical_keys.add(cand_key)
                    break

            if replacement:
                cleaned_attractions.append(replacement)
            else:
                # Pool exhausted: add flexible authentic activity instead of repeating
                act = backup_activities[backup_index % len(backup_activities)]
                backup_index += 1
                cleaned_attractions.append(act)
                if len(cleaned_attractions) >= 2:
                    break

        # Clean route string from off-route mentions
        clean_route = day.get("route", f"{departing} ➔ {destination}")
        for fb in forbidden_keywords:
            if fb in clean_route.lower():
                clean_route = f"{departing} ➔ {destination} Sightseeing Trail"
                break

        # Clean activities from off-route mentions
        clean_activities = []
        for act in day.get("activities", []):
            if not any(fb in act.lower() for fb in forbidden_keywords):
                clean_activities.append(act)
        if not clean_activities:
            clean_activities = [
                f"Guided sightseeing of {cleaned_attractions[0]}",
                "Scenic photography & local cultural exploration",
                "Authentic traditional dining experience"
            ]

        corrected_day = dict(day)
        corrected_day["dayNumber"] = day_num
        corrected_day["route"] = clean_route
        corrected_day["attractions"] = cleaned_attractions
        corrected_day["activities"] = clean_activities
        corrected_days.append(corrected_day)

    return corrected_days


# ──────────────────────────────────────────────
# SYSTEM PROMPTS WITH ROUTE-RELEVANCE RULES
# ──────────────────────────────────────────────

SYSTEM_PROMPT_TOUR_PLANNING = """You are Bon Voyage Pakistan's premier AI Tour Planning Specialist.
Your mission is to generate authentic, geographically accurate, non-repetitive day-by-day travel itineraries across Pakistan tailored strictly to verified real-world facts.

CRITICAL ROUTE & DEDUPLICATION RULES:
1. ONLY USE RELEVANT ON-ROUTE ATTRACTIONS: Only use attractions that are on the direct transit corridor or inside the destination city. A real attraction MUST STILL BE REJECTED if it is off-route or creates an unreasonable detour (e.g. NEVER include Murree or Khanpur Dam on an Islamabad ➔ Lahore trip).
2. ZERO ATTRACTION REPETITION: Each major attraction must appear ONLY ONCE in the entire itinerary across all days. Do not repeat the same attraction on different days under the same or altered wording.
3. NEVER INVENT ATTRACTIONS OR TRAILS: Never fabricate mountains, hiking trails, or fake spots in locations where they do not physically exist.
4. PREFER TRUTH OVER FABRICATION: Prefer stating 'No verified match found' or scheduling leisure/culinary time over fabricating non-existent places or duplicating locations.

FORMATTING CONSTRAINTS:
1. STRICTLY NO REASONING BLOCKS: Do NOT output any <reason>, <thought>, <think>, or scratchpad tags.
2. STRICTLY NO HASHTAGS: Do NOT use markdown heading symbols (#, ##, ###) anywhere.
3. STRICTLY NO ASTERISKS: Do NOT use asterisks (*, **, ***) for bold, italics, or list bullets.
4. ALLOWED STYLING: When emphasis or styling is needed in textual descriptions, ONLY use HTML tags:
   - <b>bold text</b> for bold emphasis
   - <i>italic text</i> for italics or local Urdu terms (e.g. <i>Chapshuro</i>, <i>Karahi</i>, <i>Dastarkhwan</i>)
   - <u>underlined text</u> for underline
   - Use the unicode bullet character • for bullet points if needed.
5. AUTHENTICITY, DIVERSITY & DISTINCT DAYS:
   - Every single day in daysPlan MUST be completely distinct and non-repetitive.
   - Day 1 should cover scenic travel from departure city along direct highway corridors (e.g. M-2 Motorway, Karakoram Highway, Swat Motorway) with legitimate corridor waypoints.
   - Subsequent days should explore specific non-repetitive valleys, iconic lakes, historical forts, or cultural bazaars with unique spots for each day.
   - Final day should cover return transit, souvenir shopping, and farewell viewpoints.
   - Include authentic regional cuisines (e.g., <i>Sohan Halwa</i>, <i>Chapshuro</i>, <i>Balti Gosht</i>, <i>Swat River Trout</i>, <i>Shinwari Karahi</i>, <i>Sajji</i>, <i>Dum Pukht</i>) and specific stays.
6. JSON OUTPUT ONLY:
   - Your response MUST be a single valid JSON object matching the exact schema below.

JSON SCHEMA:
{
  "title": "Inspiring title for the trip (e.g., 4-Day Lahore Mughal Heritage & Culinary Expedition)",
  "overview": "Brief inspiring overview of the expedition styled with <b>bold</b>, <i>italics</i>, or <u>underline</u> and NO asterisks or hashtags.",
  "departingCity": "Departure city name",
  "destinationCity": "Destination name",
  "days": 5,
  "interests": ["Interest 1", "Interest 2"],
  "transportation": "Recommended mode of travel and vehicle type",
  "accommodation": "Recommended lodging type and vibe",
  "daysPlan": [
    {
      "dayNumber": 1,
      "title": "Catchy distinct title for Day 1",
      "route": "City A ➔ Waypoint 1 ➔ Waypoint 2 ➔ Final Stop",
      "timing": "07:00 AM – 06:00 PM • Approx travel & exploration time",
      "attractions": ["Distinct Spot 1", "Distinct Spot 2", "Distinct Spot 3"],
      "activities": ["Activity 1", "Activity 2", "Activity 3"],
      "foodRecommendation": "Authentic regional food with <b>bold</b> or <i>italics</i>",
      "stayRecommendation": "Recommended hotel / resort in the area"
    }
  ]
}
"""


SYSTEM_PROMPT_TOUR_CHAT = """You are Bon Voyage Pakistan's AI Tour Planning Specialist.
You are interacting with a traveler who has generated a trip plan in Pakistan and wants to refine, alter, customize, or ask questions about their itinerary.

CRITICAL ROUTE & DEDUPLICATION RULES:
1. Do NOT suggest off-route locations (e.g. no Murree for Lahore trips).
2. Do NOT duplicate attractions across multiple days.
3. Explain adjustments clearly and warmly with <b>bold</b> or <i>italics</i>.
4. Return the updated full daysPlan with all days clearly numbered and customized.

FORMATTING CONSTRAINTS:
1. STRICTLY NO REASONING BLOCKS: Do NOT output any <reason>, <thought>, <think>, or scratchpad tags.
2. STRICTLY NO HASHTAGS: Do NOT use markdown heading symbols (#, ##, ###) anywhere.
3. STRICTLY NO ASTERISKS: Do NOT use asterisks (*, **, ***) for bold, italics, or list bullets.
4. ALLOWED STYLING: ONLY use <b>, <i>, <u> and • bullets.
5. JSON OUTPUT ONLY with schema:
{
  "message": "AI conversational response describing the changes using <b>bold</b>, <i>italics</i>, <u>underline</u> and • bullets.",
  "updatedTitle": "Updated trip title if customized",
  "updatedDaysPlan": [
    {
      "dayNumber": 1,
      "title": "Updated Title for Day 1",
      "route": "Updated route ➔ stops",
      "timing": "Updated timing",
      "attractions": ["Updated Attraction 1", "Attraction 2"],
      "activities": ["Updated Activity 1", "Activity 2"],
      "foodRecommendation": "Updated food recommendation",
      "stayRecommendation": "Updated stay recommendation"
    }
  ]
}
"""


def generate_plan(
    departing: str,
    destination: str,
    days: int,
    interests: List[str],
    special_requirements: str = ""
) -> Dict[str, Any]:
    """
    Generate a full structured Pakistan trip plan using Groq AI with route corridor validation and deduplication.
    """
    # ── STEP 1: VALIDATE DESTINATION AGAINST INTERESTS ──
    validation = validate_destination_interests(destination, interests)
    
    # If all selected interests are unsupported, return clear incompatibility response
    if not validation["is_valid"]:
        return {
            "incompatible": True,
            "message": validation["message"],
            "suggestedInterests": validation.get("suggested_interests", []),
            "suggestedDestinations": validation.get("alternative_destinations", [])
        }

    client = get_groq_client()
    if not client:
        raise ValueError("GROQ_API_KEY_TripPlan is not configured in backend/.env")

    # ── STEP 2: ROUTE CORRIDOR & EN-ROUTE ATTRACTION FILTERING ──
    allowed_enroute, forbidden_offroute = get_route_corridor_rules(departing, destination)

    # Build filtered, route-relevant candidate attraction list
    candidate_attractions: List[str] = []
    
    # Add allowed en-route waypoints first (for travel days)
    for er in allowed_enroute:
        candidate_attractions.append(er)

    # Add destination verified attractions that match supported interests and are NOT forbidden
    for da in validation.get("verified_attractions", []):
        if not any(fb in da.lower() for fb in forbidden_offroute):
            candidate_attractions.append(da)

    # Deduplicate candidate pool
    unique_candidates: List[str] = []
    seen_cand_keys: Set[str] = set()
    for c in candidate_attractions:
        ck = normalize_attraction_key(c)
        if ck not in seen_cand_keys:
            seen_cand_keys.add(ck)
            unique_candidates.append(c)

    verified_attractions_text = "\n".join([f"• {a}" for a in unique_candidates]) if unique_candidates else "Use strictly verified real on-route places."
    supported_ints_text = ", ".join(validation.get("supported_interests", [])) if validation.get("supported_interests") else "General Sightseeing & Culture"
    unsupported_ints_text = ", ".join(validation.get("unsupported_interests", [])) if validation.get("unsupported_interests") else "None"

    corridor_guidance = ""
    if allowed_enroute:
        corridor_guidance = f"Legitimate highway transit stops for Day 1: {', '.join(allowed_enroute[:3])}."

    user_message = f"""Please generate a detailed travel itinerary with the following verified route constraints:
- Departure City: {departing}
- Destination: {destination}
- Total Duration: {days} Days
- Supported Traveler Interests: {supported_ints_text}
- Unsupported Interests in this Destination: {unsupported_ints_text}
- Special Requirements / Preferences: {special_requirements if special_requirements else 'None'}
{corridor_guidance}

VERIFIED ON-ROUTE ATTRACTION POOL (USE ONLY THESE, NO OFF-ROUTE PLACES):
{verified_attractions_text}

STRICT ANTI-HALLUCINATION & DEDUPLICATION RULES:
1. Use ONLY the provided attractions on the direct route or destination.
2. A real attraction MUST STILL BE REJECTED if it is off-route or creates an unnecessary detour.
3. Each attraction must appear ONLY ONCE in the entire itinerary across all days. Do not repeat attractions.
4. If an interest is unsupported, explicitly state this in the overview and focus on verified local highlights.
Remember: Respond strictly in JSON format. NO <reason> blocks, NO hashtags (#), NO asterisks (*). Use <b>, <i>, <u> for text styling."""

    content = None
    last_error = None

    # Try primary model, fallback if needed
    for model in [MODEL_NAME, FALLBACK_MODEL_NAME]:
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT_TOUR_PLANNING},
                    {"role": "user", "content": user_message},
                ],
                response_format={"type": "json_object"},
                temperature=0.5,
            )
            content = response.choices[0].message.content
            if content:
                break
        except Exception as e:
            last_error = e
            continue

    if not content:
        raise RuntimeError(f"Failed to generate tour plan via Groq AI: {last_error}")

    # Parse and sanitize
    raw_data = json.loads(content)
    sanitized_data = sanitize_json_data(raw_data)

    # ── STEP 3: POST-GENERATION VALIDATION & DEDUPLICATION ──
    raw_days_plan = sanitized_data.get("daysPlan", [])
    corrected_days_plan = validate_and_deduplicate_itinerary(
        days_plan=raw_days_plan,
        departing=departing,
        destination=destination,
        verified_pool=unique_candidates
    )

    # Format into full TripPlan structure
    plan_id = f"TRIP-{uuid.uuid4().hex[:8].upper()}"
    title = sanitized_data.get("title", f"{days}-Day {destination} AI Discovery Plan")
    overview = sanitized_data.get("overview", "")
    transportation = sanitized_data.get("transportation", "Scenic Route Transport")
    accommodation = sanitized_data.get("accommodation", "Curated Tourist Lodges")
    quick_suggestions = sanitized_data.get("quickSuggestions", [
        "Add more photography viewpoints 📸",
        "I want more historical places 🏛️",
        "Suggest best local food spots 🍲",
        "Make route easier for families 👨‍👩‍👧"
    ])

    budget_breakdown = {
        "transportPkr": 0,
        "accommodationPkr": 0,
        "foodPkr": 0,
        "activitiesPkr": 0,
        "contingencyPkr": 0
    }

    full_plan = {
        "id": plan_id,
        "title": title,
        "departingCity": departing,
        "destinationCity": destination,
        "days": days,
        "travelers": 1,
        "budgetTier": "Curated Spots Guide",
        "budgetAmountPkr": 0.0,
        "interests": interests,
        "transportation": transportation,
        "accommodation": accommodation,
        "specialRequirements": special_requirements,
        "daysPlan": corrected_days_plan,
        "budgetBreakdown": budget_breakdown,
        "isFinalized": False
    }

    # Generate introduction chat message dynamically matching actual inputs
    interests_str = ", ".join(interests) if interests else "Sightseeing & Culture"
    intro_message = (
        f"Salam & welcome! 🇵🇰 I have prepared your personalized <b>{days}-Day {destination}</b> trip plan departing from <b>{departing}</b> focusing on <b>{interests_str}</b>.\n\n"
        f"<b><u>Trip Overview:</u></b>\n"
        f"• <b>Route:</b> {departing} ➔ {destination}\n"
        f"• <b>Duration:</b> {days} Days\n"
        f"• <b>Interests:</b> {interests_str}\n\n"
        f"{overview}\n\n"
        f"You can chat with me to fine-tune spots, adjust pace, or add specific attractions. When you're ready, tap <b>Review Plan Summary & Finalize</b> below to review your detailed day-by-day itinerary and save your trip!"
    )
    intro_message = sanitize_ai_text(intro_message)

    return {
        "plan": full_plan,
        "introMessage": intro_message,
        "quickSuggestions": quick_suggestions
    }


def chat_refinement(
    message: str,
    current_plan: Optional[Dict[str, Any]] = None,
    chat_history: Optional[List[Dict[str, Any]]] = None
) -> Dict[str, Any]:
    """
    Interactive chat refinement of the current trip plan with route validation.
    """
    client = get_groq_client()
    if not client:
        raise ValueError("GROQ_API_KEY_TripPlan is not configured in backend/.env")

    destination = current_plan.get("destinationCity", "Pakistan") if current_plan else "Pakistan"
    departing = current_plan.get("departingCity", "Islamabad") if current_plan else "Islamabad"
    
    allowed_enroute, forbidden_offroute = get_route_corridor_rules(departing, destination)
    
    dest_entry = find_destination_entry(destination)
    verified_attractions = []
    for er in allowed_enroute:
        verified_attractions.append(er)
    if dest_entry and "attractions" in dest_entry:
        for cat_list in dest_entry["attractions"].values():
            for da in cat_list:
                if not any(fb in da.lower() for fb in forbidden_offroute):
                    verified_attractions.append(da)

    plan_context = ""
    if current_plan:
        plan_context = f"""
CURRENT ACTIVE TOUR PLAN:
- Title: {current_plan.get('title')}
- Route: {current_plan.get('departingCity')} ➔ {current_plan.get('destinationCity')} ({current_plan.get('days')} Days)
- Current Days Plan: {json.dumps(current_plan.get('daysPlan', []), indent=2)}
- Verified Real On-Route Landmarks: {', '.join(verified_attractions[:15]) if verified_attractions else 'Use real on-route spots.'}
- Forbidden Off-Route Places: {', '.join(forbidden_offroute) if forbidden_offroute else 'None'}
"""

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT_TOUR_CHAT},
        {"role": "system", "content": f"Context for this conversation:\n{plan_context}\nStrict rule: Never invent fake attractions or introduce off-route detours."},
    ]

    if chat_history:
        for chat_msg in chat_history[-6:]:
            role = "assistant" if chat_msg.get("isAi") else "user"
            text = chat_msg.get("text", "")
            if text:
                messages.append({"role": role, "content": text})

    messages.append({"role": "user", "content": message})

    content = None
    last_error = None

    for model in [MODEL_NAME, FALLBACK_MODEL_NAME]:
        try:
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                response_format={"type": "json_object"},
                temperature=0.5,
            )
            content = response.choices[0].message.content
            if content:
                break
        except Exception as e:
            last_error = e
            continue

    if not content:
        raise RuntimeError(f"Failed to refine chat via Groq AI: {last_error}")

    raw_data = json.loads(content)
    sanitized_data = sanitize_json_data(raw_data)

    ai_message = sanitized_data.get("message", "I have updated your tour itinerary with your requested changes.")
    raw_updated_days_plan = sanitized_data.get("updatedDaysPlan")
    updated_title = sanitized_data.get("updatedTitle")

    updated_full_plan = None
    if current_plan and raw_updated_days_plan:
        corrected_updated_days = validate_and_deduplicate_itinerary(
            days_plan=raw_updated_days_plan,
            departing=departing,
            destination=destination,
            verified_pool=verified_attractions
        )
        updated_full_plan = dict(current_plan)
        if updated_title:
            updated_full_plan["title"] = updated_title
        updated_full_plan["daysPlan"] = corrected_updated_days

    return {
        "message": ai_message,
        "updatedPlan": updated_full_plan
    }

