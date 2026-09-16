import 'package:flutter/material.dart';
import 'package:agrifor_app/models/property_detail_view_data.dart';
import 'package:agrifor_app/services/external_link_service.dart';

/// Tela de detalhes de uma propriedade, alimentada por dados reais do
/// Firestore.
///
/// Recebe um único PropertyDetailViewData já pronto — a tela não sabe
/// (nem precisa saber) como ids viram nomes de exibição, isso é
/// responsabilidade de quem a abriu.
///
/// Mantém a tela puramente de apresentação.
class PropertyDetailScreen extends StatelessWidget {
  const PropertyDetailScreen({
    super.key,
    required this.data,
    this.showBackButton = true,
    this.showCollapsedHeader = true,
    this.onEdit,
    this.onResubmit,
  });

  final PropertyDetailViewData data;

  /// false quando a tela é embutida como conteúdo de uma aba.
  final bool showBackButton;

  /// Define se, ao recolher o header, deve permanecer uma barra verde
  /// com o nome da propriedade.
  ///
  /// true: admin/mapa.
  /// false: Minha Propriedade.
  final bool showCollapsedHeader;

  /// Quando não-nulo, mostra o botão "Editar propriedade".
  final VoidCallback? onEdit;

  /// Quando não-nulo e a propriedade estiver rejeitada,
  /// mostra o botão "Submeter novamente".
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    final property = data.property;

    final hasContact =
        property.whatsapp.isNotEmpty ||
        property.phone.isNotEmpty ||
        property.instagram.isNotEmpty;

    final location = property.location;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),

      floatingActionButton: onEdit == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onEdit,
              backgroundColor:
                  const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              icon: const Icon(
                Icons.edit_outlined,
              ),
              label: const Text(
                'Editar propriedade',
              ),
            ),

      body: CustomScrollView(
        slivers: [
          // HEADER
          SliverAppBar(
            backgroundColor:
                showCollapsedHeader
                    ? const Color(0xFF2E7D32)
                    : Colors.transparent,

            expandedHeight: 200,

            primary: showCollapsedHeader,

            toolbarHeight:
                showCollapsedHeader
                    ? kToolbarHeight
                    : 0,

            collapsedHeight:
                showCollapsedHeader
                    ? null
                    : 0,

            pinned:
                showCollapsedHeader &&
                showBackButton,

            automaticallyImplyLeading:
                showBackButton,

            centerTitle: false,

            leading: showBackButton
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        Navigator.pop(context),
                  )
                : null,

            flexibleSpace: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final topPadding =
                    MediaQuery.paddingOf(
                      context,
                    ).top;

                final maxHeight =
                    200.0 +
                    (showCollapsedHeader
                        ? topPadding
                        : 0);

                final minHeight =
                    showCollapsedHeader
                        ? kToolbarHeight +
                            topPadding
                        : 0.0;

                final currentHeight =
                    constraints.biggest.height;

                final availableRange =
                    maxHeight - minHeight;

                final collapseProgress =
                    availableRange <= 0
                        ? 1.0
                        : ((maxHeight -
                                    currentHeight) /
                                availableRange)
                            .clamp(
                              0.0,
                              1.0,
                            )
                            .toDouble();

                // Nome no topo só começa a aparecer
                // quando a barra está praticamente recolhida.
                final titleOpacity =
                    showCollapsedHeader
                        ? ((collapseProgress -
                                        0.90) /
                                    0.10)
                                .clamp(
                                  0.0,
                                  1.0,
                                )
                                .toDouble()
                        : 0.0;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    FlexibleSpaceBar(
                      background: Stack(
                        fit:
                            StackFit.expand,
                        children: [
                          // CARROSSEL
                          _PropertyImageCarousel(
                            images:
                                property.images,
                          ),

                          // GRADIENTE
                          const IgnorePointer(
                            child: DecoratedBox(
                              decoration:
                                  BoxDecoration(
                                gradient:
                                    LinearGradient(
                                  begin: Alignment
                                      .topCenter,
                                  end: Alignment
                                      .bottomCenter,
                                  stops: [
                                    0.55,
                                    1.0,
                                  ],
                                  colors: [
                                    Colors
                                        .transparent,
                                    Colors
                                        .black45,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // NOME SOBRE A FOTO
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 14,
                            child:
                                IgnorePointer(
                              child:
                                  Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      14,
                                  vertical: 6,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .black
                                      .withValues(
                                    alpha:
                                        0.32,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child: Text(
                                  property
                                      .propertyName,
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style:
                                      const TextStyle(
                                    color: Colors
                                        .white,
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // NOME NA BARRA VERDE RECOLHIDA
                    if (showCollapsedHeader)
                      Positioned(
                        left:
                            showBackButton
                                ? 56
                                : 16,
                        right: 16,
                        bottom: 16,
                        child:
                            IgnorePointer(
                          child: Opacity(
                            opacity:
                                titleOpacity,
                            child: Text(
                              property
                                  .propertyName,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          SliverPadding(
            padding:
                const EdgeInsets.all(20),
            sliver: SliverList(
              delegate:
                  SliverChildListDelegate(
                [
                  // PENDENTE
                  if (property.isPending) ...[
                    Container(
                      padding:
                          const EdgeInsets
                              .all(14),
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFFFFF8E1,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFFFFE082,
                          ),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Icon(
                            Icons
                                .hourglass_top,
                            color: Color(
                              0xFFF9A825,
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              'Seu cadastro está aguardando aprovação. Assim que for aprovado, '
                              'a propriedade ficará visível ao público.',
                              style:
                                  TextStyle(
                                fontSize:
                                    13,
                                color:
                                    Color(
                                  0xFF5D4037,
                                ),
                                height:
                                    1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  // REJEITADO
                  if (property
                      .isRejected) ...[
                    Container(
                      padding:
                          const EdgeInsets
                              .all(14),
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFFFFEBEE,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFFEF9A9A,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Icon(
                                Icons
                                    .cancel_outlined,
                                color:
                                    Color(
                                  0xFFC62828,
                                ),
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Text(
                                  'Seu cadastro não foi aprovado. Revise as informações da propriedade '
                                  'e envie novamente para análise.',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        13,
                                    color:
                                        Color(
                                      0xFFB71C1C,
                                    ),
                                    height:
                                        1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (onResubmit !=
                              null) ...[
                            const SizedBox(
                              height: 12,
                            ),
                            SizedBox(
                              width: double
                                  .infinity,
                              child:
                                  FilledButton
                                      .icon(
                                onPressed:
                                    onResubmit,
                                style:
                                    FilledButton
                                        .styleFrom(
                                  backgroundColor:
                                      const Color(
                                    0xFFC62828,
                                  ),
                                ),
                                icon:
                                    const Icon(
                                  Icons
                                      .send_outlined,
                                  size: 18,
                                ),
                                label:
                                    const Text(
                                  'Submeter novamente',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  // RESUMO
                  if (property
                      .summary
                      .isNotEmpty) ...[
                    _SectionCard(
                      title:
                          'Sobre a propriedade',
                      icon:
                          Icons.info_outline,
                      child: Text(
                        property.summary,
                        style:
                            const TextStyle(
                          fontSize: 13,
                          color:
                              Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  // CATEGORIAS
                  if (data
                      .categoryNames
                      .isNotEmpty) ...[
                    _SectionCard(
                      title: 'Categorias',
                      icon: Icons
                          .category_outlined,
                      child: _ChipWrap(
                        items: data
                            .categoryNames,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  // PRODUTOS
                  if (data
                      .productNames
                      .isNotEmpty) ...[
                    _SectionCard(
                      title: 'Produtos',
                      icon:
                          Icons.eco_outlined,
                      child: _ChipWrap(
                        items:
                            data.productNames,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  // SISTEMA DE PRODUÇÃO
                  if (data
                      .productionSystemNames
                      .isNotEmpty) ...[
                    _SectionCard(
                      title:
                          'Sistema de produção',
                      icon: Icons
                          .agriculture_outlined,
                      child: _ChipWrap(
                        items: data
                            .productionSystemNames,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  // CANAIS DE VENDA
                  if (property
                      .salesChannels
                      .isNotEmpty) ...[
                    _SectionCard(
                      title:
                          'Canais de Venda',
                      icon: Icons
                          .storefront_outlined,
                      child: _ChipWrap(
                        items: property
                            .salesChannels,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  // CONTATO
                  _SectionCard(
                    title: 'Contato',
                    icon: Icons
                        .contact_phone_outlined,
                    child: hasContact
                        ? Column(
                            children: [
                              if (property
                                  .whatsapp
                                  .isNotEmpty)
                                _ContactTile(
                                  icon: Icons
                                      .chat_outlined,
                                  color:
                                      const Color(
                                    0xFF25D366,
                                  ),
                                  label:
                                      'WhatsApp',
                                  onTap: () =>
                                      ExternalLinkService
                                          .openWhatsApp(
                                    context,
                                    property
                                        .whatsapp,
                                  ),
                                ),

                              if (property
                                      .whatsapp
                                      .isNotEmpty &&
                                  (property
                                          .phone
                                          .isNotEmpty ||
                                      property
                                          .instagram
                                          .isNotEmpty))
                                const Divider(
                                  height: 1,
                                ),

                              if (property
                                  .phone
                                  .isNotEmpty)
                                _ContactTile(
                                  icon: Icons
                                      .phone_outlined,
                                  color:
                                      const Color(
                                    0xFF2E7D32,
                                  ),
                                  label:
                                      'Telefone',
                                  onTap: () =>
                                      ExternalLinkService
                                          .callPhone(
                                    context,
                                    property
                                        .phone,
                                  ),
                                ),

                              if (property
                                      .phone
                                      .isNotEmpty &&
                                  property
                                      .instagram
                                      .isNotEmpty)
                                const Divider(
                                  height: 1,
                                ),

                              if (property
                                  .instagram
                                  .isNotEmpty)
                                _ContactTile(
                                  icon: Icons
                                      .camera_alt_outlined,
                                  color:
                                      const Color(
                                    0xFFC13584,
                                  ),
                                  label:
                                      'Instagram',
                                  onTap: () =>
                                      ExternalLinkService
                                          .openInstagram(
                                    context,
                                    property
                                        .instagram,
                                  ),
                                ),
                            ],
                          )
                        : const Text(
                            'Nenhum contato informado.',
                            style:
                                TextStyle(
                              fontSize: 13,
                              color: Colors
                                  .black45,
                            ),
                          ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // LOCALIZAÇÃO
                  if (location != null)
                    _SectionCard(
                      title: 'Localização',
                      icon:
                          Icons.map_outlined,
                      child: _ContactTile(
                        icon: Icons.map,
                        color:
                            const Color(
                          0xFF4285F4,
                        ),
                        label:
                            'Abrir rota no Google Maps',
                        onTap: () =>
                            ExternalLinkService
                                .openGoogleMaps(
                          context,
                          latitude: location
                              .latitude,
                          longitude: location
                              .longitude,
                        ),
                      ),
                    ),

                  if (onEdit != null)
                    const SizedBox(
                      height: 72,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrossel de fotos exibido no header.
class _PropertyImageCarousel
    extends StatefulWidget {
  const _PropertyImageCarousel({
    required this.images,
  });

  final List<String> images;

  @override
  State<_PropertyImageCarousel>
      createState() =>
          _PropertyImageCarouselState();
}

class _PropertyImageCarouselState
    extends State<_PropertyImageCarousel> {
  final PageController _pageController =
      PageController();

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        color: const Color(0xFF2E7D32),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: Colors.white38,
          size: 48,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (
            context,
            index,
          ) {
            return Container(
              color:
                  const Color(0xFF1B5E20),
              child: Image.network(
                widget.images[index],
                fit: BoxFit.cover,
                loadingBuilder: (
                  context,
                  child,
                  progress,
                ) {
                  if (progress == null) {
                    return child;
                  }

                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color: Colors.white70,
                    ),
                  );
                },
                errorBuilder: (
                  context,
                  error,
                  stack,
                ) =>
                    const Center(
                  child: Icon(
                    Icons
                        .broken_image_outlined,
                    color: Colors.white38,
                    size: 48,
                  ),
                ),
              ),
            );
          },
        ),

        if (widget.images.length > 1)
          Positioned(
            bottom: 58,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) {
                    final active =
                        index ==
                        _currentPage;

                    return AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 200,
                      ),
                      margin:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 3,
                      ),
                      width:
                          active ? 16 : 6,
                      height: 6,
                      decoration:
                          BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors
                                .white38,
                        borderRadius:
                            BorderRadius
                                .circular(
                          3,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.05,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color:
                    const Color(0xFF2E7D32),
                size: 18,
              ),
              const SizedBox(
                width: 8,
              ),
              Text(
                title,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                  color:
                      Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap
    extends StatelessWidget {
  final List<String> items;

  const _ChipWrap({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map(
        (item) {
          return Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color: const Color(
                0xFFE8F5E9,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                20,
              ),
            ),
            child: Text(
              item,
              style:
                  const TextStyle(
                color: Color(
                  0xFF2E7D32,
                ),
                fontWeight:
                    FontWeight.w600,
                fontSize: 13,
              ),
            ),
          );
        },
      ).toList(),
    );
  }
}

class _ContactTile
    extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          EdgeInsets.zero,
      leading: Container(
        padding:
            const EdgeInsets.all(8),
        decoration:
            BoxDecoration(
          color: color.withValues(
            alpha: 0.1,
          ),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style:
            const TextStyle(
          fontSize: 14,
        ),
      ),
      trailing:
          const Icon(
        Icons.chevron_right,
        color: Colors.black26,
      ),
      onTap: onTap,
    );
  }
}