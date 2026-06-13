import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class VehicleInspectionApp extends StatelessWidget {
  const VehicleInspectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Form Inspeksi Kendaraan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: const VehicleInspectionFormPage(),
    );
  }
}

enum ExteriorCondition {
  baik('Baik'),
  lecetRingan('Lecet Ringan'),
  rusak('Rusak'),
  sangatRusak('Sangat Rusak');

  const ExteriorCondition(this.label);

  final String label;
}

enum EngineCondition {
  hidupNormal('Hidup Normal'),
  hidupTidakNormal('Hidup Tidak Normal'),
  mati('Mati');

  const EngineCondition(this.label);

  final String label;
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;

  factory LocationSnapshot.fromPosition(Position position) {
    return LocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }

  String get shortLabel {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  String get detailLabel {
    return 'Lat ${latitude.toStringAsFixed(5)}, Long ${longitude.toStringAsFixed(5)} | Akurasi ${accuracy.toStringAsFixed(0)} m';
  }
}

class CapturedInspectionPhoto {
  const CapturedInspectionPhoto({
    required this.bytes,
    required this.capturedAt,
    required this.location,
  });

  final Uint8List bytes;
  final DateTime capturedAt;
  final LocationSnapshot location;

  String get watermarkText {
    return '${location.shortLabel} | ${formatDateTime(capturedAt)}';
  }
}

class VehicleInspectionFormPage extends StatefulWidget {
  const VehicleInspectionFormPage({super.key});

  @override
  State<VehicleInspectionFormPage> createState() {
    return _VehicleInspectionFormPageState();
  }
}

class _VehicleInspectionFormPageState extends State<VehicleInspectionFormPage> {
  static const List<String> requiredPhotoLabels = [
    'Depan',
    'Belakang',
    'Kiri',
    'Kanan',
    'Speedometer',
  ];

  final formKey = GlobalKey<FormState>();
  final plateController = TextEditingController();
  final kilometerController = TextEditingController();
  final addressController = TextEditingController();
  final cannotMoveReasonController = TextEditingController();
  final notesController = TextEditingController();
  final imagePicker = ImagePicker();

  final Map<String, CapturedInspectionPhoto> photos = {};
  final List<Offset?> signaturePoints = [];

  ExteriorCondition? exteriorCondition;
  EngineCondition? engineCondition;
  bool? canBeMoved;
  LocationSnapshot? currentLocation;
  bool isLoadingLocation = false;
  bool isCapturingPhoto = false;
  bool hasSubmitted = false;
  String? locationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCurrentLocation(silent: true);
    });
  }

  @override
  void dispose() {
    plateController.dispose();
    kilometerController.dispose();
    addressController.dispose();
    cannotMoveReasonController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> loadCurrentLocation({bool silent = false}) async {
    setState(() {
      isLoadingLocation = true;
      locationError = null;
    });

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        throw Exception('GPS perangkat belum aktif');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi belum diberikan');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentLocation = LocationSnapshot.fromPosition(position);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        locationError = error.toString().replaceFirst('Exception: ', '');
      });

      if (!silent) {
        showMessage(locationError ?? 'Gagal mengambil GPS');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingLocation = false;
        });
      }
    }
  }

  Future<LocationSnapshot> getLocationForPhoto() async {
    if (currentLocation != null) {
      return currentLocation!;
    }

    await loadCurrentLocation(silent: false);

    final location = currentLocation;
    if (location == null) {
      throw Exception('GPS wajib aktif sebelum mengambil foto');
    }

    return location;
  }

  Future<void> capturePhoto(String label) async {
    if (isCapturingPhoto) return;

    setState(() {
      isCapturingPhoto = true;
    });

    try {
      final location = await getLocationForPhoto();
      final photo = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();

      if (!mounted) return;

      setState(() {
        photos[label] = CapturedInspectionPhoto(
          bytes: bytes,
          capturedAt: DateTime.now(),
          location: location,
        );
      });
    } catch (error) {
      if (!mounted) return;

      showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isCapturingPhoto = false;
        });
      }
    }
  }

  void submitForm() {
    setState(() {
      hasSubmitted = true;
    });

    final isFormValid = formKey.currentState?.validate() ?? false;
    final hasAllPhotos = requiredPhotoLabels.every(photos.containsKey);
    final hasGps = currentLocation != null;
    final hasSignature = signaturePoints.whereType<Offset>().length >= 2;

    if (!isFormValid || !hasAllPhotos || !hasGps || !hasSignature) {
      showMessage('Lengkapi semua field wajib sebelum submit');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Inspeksi siap dikirim'),
          content: Text(
            'Nomor Polisi: ${plateController.text.trim().toUpperCase()}\n'
            'Kilometer: ${kilometerController.text.trim()} km\n'
            'Lokasi: ${currentLocation!.detailLabel}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? validatePlateNumber(String? value) {
    final plate = value?.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    if (plate == null || plate.isEmpty) {
      return 'Nomor polisi wajib diisi';
    }

    final platePattern = RegExp(r'^[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3}$');
    if (!platePattern.hasMatch(plate)) {
      return 'Format plat tidak valid, contoh: B 1234 ABC';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Inspeksi Kendaraan'),
        actions: [
          IconButton(
            tooltip: 'Ambil ulang GPS',
            onPressed: isLoadingLocation ? null : loadCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionHeader(
                icon: Icons.directions_car_filled_outlined,
                title: 'Data Kendaraan',
              ),
              TextFormField(
                controller: plateController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 ]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nomor Polisi',
                  hintText: 'B 1234 ABC',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: validatePlateNumber,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: kilometerController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Kilometer Saat Ini',
                  suffixText: 'km',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kilometer wajib diisi';
                  }

                  final kilometer = int.tryParse(value);
                  if (kilometer == null || kilometer < 0) {
                    return 'Kilometer harus angka valid';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 20),
              SectionHeader(
                icon: Icons.photo_camera_outlined,
                title: 'Dokumentasi Foto',
              ),
              Text(
                'Semua foto diambil dari kamera dan wajib memiliki watermark GPS serta waktu.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 620;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: requiredPhotoLabels.length,
                    itemBuilder: (context, index) {
                      final label = requiredPhotoLabels[index];
                      return PhotoCaptureTile(
                        label: label,
                        photo: photos[label],
                        showError: hasSubmitted && photos[label] == null,
                        isBusy: isCapturingPhoto,
                        onTap: () => capturePhoto(label),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              SectionHeader(
                icon: Icons.fact_check_outlined,
                title: 'Kondisi Kendaraan',
              ),
              DropdownButtonFormField<ExteriorCondition>(
                initialValue: exteriorCondition,
                decoration: const InputDecoration(
                  labelText: 'Kondisi Eksterior',
                  prefixIcon: Icon(Icons.car_repair_outlined),
                ),
                items: ExteriorCondition.values.map((condition) {
                  return DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    exteriorCondition = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Kondisi eksterior wajib dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<EngineCondition>(
                initialValue: engineCondition,
                decoration: const InputDecoration(
                  labelText: 'Kondisi Mesin',
                  prefixIcon: Icon(Icons.settings_outlined),
                ),
                items: EngineCondition.values.map((condition) {
                  return DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    engineCondition = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Kondisi mesin wajib dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SectionHeader(
                icon: Icons.location_on_outlined,
                title: 'Lokasi Kendaraan Ditemukan',
              ),
              LocationPanel(
                location: currentLocation,
                errorMessage: locationError,
                isLoading: isLoadingLocation,
                showError: hasSubmitted && currentLocation == null,
                onRefresh: loadCurrentLocation,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: addressController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Keterangan Alamat',
                  hintText:
                      'Nama jalan, patokan, area parkir, atau detail lokasi',
                  prefixIcon: Icon(Icons.edit_location_alt_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Keterangan alamat wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SectionHeader(
                icon: Icons.local_shipping_outlined,
                title: 'Status Pemindahan',
              ),
              FormField<bool>(
                initialValue: canBeMoved,
                validator: (_) {
                  if (canBeMoved == null) {
                    return 'Pilih apakah kendaraan bisa dipindahkan';
                  }
                  return null;
                },
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.check_circle_outline),
                            label: Text('Ya'),
                          ),
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.cancel_outlined),
                            label: Text('Tidak'),
                          ),
                        ],
                        selected: canBeMoved == null ? {} : {canBeMoved!},
                        emptySelectionAllowed: true,
                        onSelectionChanged: (values) {
                          setState(() {
                            canBeMoved = values.isEmpty ? null : values.first;
                          });
                          field.didChange(canBeMoved);
                        },
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (canBeMoved == false) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: cannotMoveReasonController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Tidak Bisa Dipindahkan',
                    hintText:
                        'Jelaskan hambatan teknis, legal, atau kondisi lapangan',
                    prefixIcon: Icon(Icons.report_problem_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (canBeMoved != false) return null;

                    final reason = value?.trim() ?? '';
                    if (reason.isEmpty) {
                      return 'Alasan wajib diisi jika kendaraan tidak bisa dipindahkan';
                    }
                    if (reason.length < 30) {
                      return 'Alasan minimal 30 karakter';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              SectionHeader(
                icon: Icons.notes_outlined,
                title: 'Catatan dan Tanda Tangan',
              ),
              TextFormField(
                controller: notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Catatan Tambahan',
                  hintText: 'Opsional',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              SignaturePad(
                points: signaturePoints,
                showError:
                    hasSubmitted &&
                    signaturePoints.whereType<Offset>().length < 2,
                onChanged: () {
                  setState(() {});
                },
                onClear: () {
                  setState(signaturePoints.clear);
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: submitForm,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit Inspeksi'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoCaptureTile extends StatelessWidget {
  const PhotoCaptureTile({
    required this.label,
    required this.photo,
    required this.showError,
    required this.isBusy,
    required this.onTap,
    super.key,
  });

  final String label;
  final CapturedInspectionPhoto? photo;
  final bool showError;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isBusy ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: showError ? colorScheme.error : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo == null)
                ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 34,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Wajib',
                        style: TextStyle(
                          color: showError
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Image.memory(photo!.bytes, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.68),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      photo == null ? 'Kamera saja' : photo!.watermarkText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationPanel extends StatelessWidget {
  const LocationPanel({
    required this.location,
    required this.errorMessage,
    required this.isLoading,
    required this.showError,
    required this.onRefresh,
    super.key,
  });

  final LocationSnapshot? location;
  final String? errorMessage;
  final bool isLoading;
  final bool showError;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = showError
        ? colorScheme.error
        : colorScheme.outlineVariant;
    final text =
        location?.detailLabel ??
        errorMessage ??
        'GPS otomatis akan diambil dari perangkat surveyor';

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              location == null ? Icons.location_searching : Icons.gps_fixed,
              color: showError ? colorScheme.error : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? 'Mengambil GPS...' : text,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (showError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'GPS wajib berhasil diambil',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ambil ulang GPS',
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({
    required this.points,
    required this.showError,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final List<Offset?> points;
  final bool showError;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tanda Tangan Digital',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: points.isEmpty ? null : onClear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus'),
            ),
          ],
        ),
        GestureDetector(
          onPanStart: (details) {
            points.add(details.localPosition);
            onChanged();
          },
          onPanUpdate: (details) {
            points.add(details.localPosition);
            onChanged();
          },
          onPanEnd: (_) {
            points.add(null);
            onChanged();
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(
                color: showError ? colorScheme.error : colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: SignaturePainter(points),
                child: points.isEmpty
                    ? Center(
                        child: Text(
                          'Tanda tangan di area ini',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Tanda tangan digital wajib diisi',
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  const SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}
