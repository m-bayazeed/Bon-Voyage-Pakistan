import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../theme/theme_provider.dart';
import '../widgets/theme_toggle.dart';

/// Premier Live Weather & Travel Conditions Screen for Bon Voyage Pakistan.
/// Powered by OpenWeatherMap API with situational highway & mountain pass safety advisories.
class WeatherScreen extends StatefulWidget {
  final String? initialCity;

  const WeatherScreen({super.key, this.initialCity});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late String _selectedCity;
  WeatherData? _weatherData;
  bool _isLoading = true;
  String? _errorMessage;

  late List<String> _cities;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cities = List<String>.from(WeatherService.supportedCities);
    _selectedCity = widget.initialCity ?? 'Islamabad';
    if (!_cities.contains(_selectedCity)) {
      _cities.insert(0, _selectedCity);
    }
    _searchCtrl.text = _selectedCity;
    _loadWeather();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final existingIndex = _cities.indexWhere((c) => c.toLowerCase() == clean.toLowerCase());
    String finalCityName = clean;
    if (existingIndex != -1) {
      finalCityName = _cities[existingIndex];
    } else {
      final words = clean.split(RegExp(r'\s+'));
      finalCityName = words
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
      _cities.insert(0, finalCityName);
    }

    _searchCtrl.text = finalCityName;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedCity = finalCityName;
    });
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await WeatherService.fetchWeather(city: _selectedCity);
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to fetch weather data for "$_selectedCity". Please try another city or pull down to refresh.';
        });
      }
    }
  }

  void _onCityChanged(String? newCity) {
    if (newCity == null || newCity == _selectedCity) return;
    _searchCtrl.text = newCity;
    setState(() {
      _selectedCity = newCity;
    });
    _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProviderScope.of(context);
    final isDark = tp.isDark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Weather & Conditions',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'OpenWeatherMap Real-Time Feed',
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          ThemeToggle(
            isDark: tp.isDark,
            onToggle: () => tp.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWeather,
        color: const Color(0xFF0284C7),
        backgroundColor: cardBg,
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fetching live weather for $_selectedCity...',
                      style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : _errorMessage != null && _weatherData == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSearchBar(cardBg, textPrimary, textSecondary, isDark),
                      const SizedBox(height: 12),
                      _buildCitySelector(cardBg, textPrimary, textSecondary),
                      const SizedBox(height: 48),
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 60, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadWeather,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      // ── 1. City Search Bar ──
                      _buildSearchBar(cardBg, textPrimary, textSecondary, isDark),
                      const SizedBox(height: 12),

                      // ── 2. City Selector Dropdown ──
                      _buildCitySelector(cardBg, textPrimary, textSecondary),
                      const SizedBox(height: 16),

                      // ── 3. Hero Weather Card ──
                      _buildHeroCard(cardBg, textPrimary, textSecondary, isDark),
                      const SizedBox(height: 16),

                      // ── 4. Travel Safety Advisory Card ──
                      _buildAdvisoryCard(isDark),
                      const SizedBox(height: 16),

                      // ── 5. Key Meteorological Metrics Grid ──
                      _buildMetricsGrid(cardBg, textPrimary, textSecondary, isDark),
                      const SizedBox(height: 20),

                      // ── 6. Travel Tips Footer ──
                      _buildTravelTipsCard(cardBg, textPrimary, textSecondary),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSearchBar(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.35), width: 1.2),
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
        decoration: InputDecoration(
          hintText: 'Search any city (e.g. Faisalabad, Sialkot, Swat)...',
          hintStyle: TextStyle(fontSize: 12.5, color: textSecondary.withOpacity(0.75), fontWeight: FontWeight.w400),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: textSecondary),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0284C7), size: 18),
                onPressed: () => _submitSearch(_searchCtrl.text),
              ),
              const SizedBox(width: 4),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: _submitSearch,
      ),
    );
  }

  Widget _buildCitySelector(Color cardBg, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.2), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCity,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0284C7)),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                dropdownColor: cardBg,
                borderRadius: BorderRadius.circular(16),
                items: _cities.map((String city) {
                  return DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: _onCityChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final weather = _weatherData!;
    final tempStr = weather.temperature.toStringAsFixed(1);
    final feelsLikeStr = weather.feelsLike.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF0F9FF),
                ],
        ),
        border: Border.all(
          color: const Color(0xFF0284C7).withOpacity(isDark ? 0.2 : 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City Name & Live Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    weather.city,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: Color(0xFF059669)),
                    SizedBox(width: 5),
                    Text(
                      'LIVE FEED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Temperature & Weather Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tempStr,
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -2,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Feels like $feelsLikeStr°C',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),

              // OpenWeather Condition Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(isDark ? 0.15 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: Image.network(
                  weather.iconUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.wb_sunny_rounded,
                    size: 46,
                    color: weather.conditionColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weather Condition Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thermostat_rounded, size: 16, color: const Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Text(
                  '${weather.condition} • ${weather.description}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryCard(bool isDark) {
    final weather = _weatherData!;
    final advColor = weather.advisoryColor;
    final advBg = isDark ? advColor.withOpacity(0.12) : weather.advisoryBackgroundColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: advBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: advColor.withOpacity(0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: advColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: advColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  weather.isFavorable ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                  color: advColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  weather.isFavorable ? 'FAVORABLE TRAVEL CONDITIONS' : 'WEATHER & ROAD ADVISORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: advColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            weather.travelAdvisory,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final weather = _weatherData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'KEY METRICS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.water_drop_rounded,
                label: 'Humidity',
                value: '${weather.humidity}%',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accentColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.air_rounded,
                label: 'Wind Speed',
                value: '${weather.windSpeedKmh} km/h',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accentColor: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.device_thermostat_rounded,
                label: 'Feels Like',
                value: '${weather.feelsLike.toStringAsFixed(0)}°C',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accentColor: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelTipsCard(Color cardBg, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textSecondary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel Safety Reminder',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Weather in northern valleys (Hunza, Skardu, Swat) can change rapidly. Always keep emergency supplies, offline maps, and power banks ready.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
