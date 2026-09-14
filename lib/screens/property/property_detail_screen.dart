import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrifor_app/models/property_detail_view_data.dart';

/// Tela de detalhes de uma propriedade, alimentada por dados reais do
/// Firestore.
///
/// Recebe um único PropertyDetailViewData já pronto — a tela não sabe
/// (nem precisa saber) como ids viram nomes de exibição, isso é
/// responsabilidade de quem a abriu (ver AdminPropertiesController.
/// detailDataFor pro admin/mapa, ou MyPropertyScreen pro produtor).
/// Mantém a tela puramente de apresentação.
class PropertyDetailScreen extends StatelessWidget {
  const PropertyDetailScreen({
    super.key,
    required this.data,
    this.showBackButton = true,
    this.onEdit,
    this.onResubmit,
  });

  final PropertyDetailViewData data;

  /// false quando a tela é embutida como conteúdo de uma aba (ex.:
  /// "Minha Propriedade" do produtor) em vez de empurrada via
  /// Navigator.push — evita um botão de voltar que daria pop no shell
  /// errado.
  final bool showBackButton;

  /// Quando não-nulo, mostra um FAB "Editar propriedade". Usado pela
  /// visão do produtor na própria propriedade; admin continua editando
  /// pela lista (PropertiesScreen), não por aqui.
  final VoidCallback? onEdit;

  /// Quando não-nulo e a propriedade estiver `rejected`, mostra o
  /// botão "Submeter novamente" dentro do aviso de rejeição. Só
  /// MyPropertyScreen passa isso (mesmo padrão de [onEdit]) — é uma
  /// ação exclusiva do produtor dono, admin não reenvia pelo detalhe.
  final VoidCallback? onResubmit;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = data.property;
    final hasContact = property.whatsapp.isNotEmpty;
    final location = property.location;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      floatingActionButton: onEdit == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onEdit,
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar propriedade'),
            ),
      body: CustomScrollView(
        slivers: [
          // HEADER
          SliverAppBar(
            backgroundColor: const Color(0xFF2E7D32),
            expandedHeight: 200,
            pinned: true,
            automaticallyImplyLeading: showBackButton,
            leading: showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Carrossel de fotos da propriedade. Ainda sem
                  // imagens reais programadas — placeholder visual só
                  // pra reservar o espaço e o comportamento de swipe.
                  const _PropertyImageCarousel(),

                  // Escurece a parte de baixo pra o nome ficar
                  // legível por cima das fotos do carrossel.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.55, 1.0],
                        colors: [Colors.transparent, Colors.black45],
                      ),
                    ),
                  ),

                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.propertyName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // AVISO DE PENDÊNCIA — só aparece pra quem consegue
                // abrir uma propriedade pendente (o próprio criador,
                // via MyPropertyScreen, ou o admin, via PropertiesScreen).
                // Público/mapa nunca chegam aqui: watchApproved() já
                // filtra pendente antes de qualquer resolve() rodar.
                if (property.isPending) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.hourglass_top, color: Color(0xFFF9A825)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Seu cadastro está aguardando aprovação. Assim que for aprovado, '
                            'a propriedade ficará visível ao público.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5D4037),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // AVISO DE REJEIÇÃO — mesmo público-alvo do aviso de
                // pendência acima (dono e admin; watchApproved() também
                // já filtra `rejected` antes de qualquer resolve()).
                // Quando quem abriu a tela passou onResubmit (só
                // MyPropertyScreen passa), mostra o botão "Submeter
                // novamente" dentro do próprio aviso.
                if (property.isRejected) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              color: Color(0xFFC62828),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Seu cadastro não foi aprovado. Revise as informações da propriedade '
                                'e envie novamente para análise.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB71C1C),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (onResubmit != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: onResubmit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC62828),
                              ),
                              icon: const Icon(Icons.send_outlined, size: 18),
                              label: const Text('Submeter novamente'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // RESUMO
                if (property.summary.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Sobre a propriedade',
                    icon: Icons.info_outline,
                    child: Text(
                      property.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // CATEGORIAS
                if (data.categoryNames.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Categorias',
                    icon: Icons.category_outlined,
                    child: _ChipWrap(items: data.categoryNames),
                  ),
                  const SizedBox(height: 16),
                ],

                // PRODUTOS
                if (data.productNames.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Produtos',
                    icon: Icons.eco_outlined,
                    child: _ChipWrap(items: data.productNames),
                  ),
                  const SizedBox(height: 16),
                ],

                // SISTEMA DE PRODUÇÃO
                if (data.productionSystemNames.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Sistema de produção',
                    icon: Icons.agriculture_outlined,
                    child: _ChipWrap(items: data.productionSystemNames),
                  ),
                  const SizedBox(height: 16),
                ],

                // CANAIS DE VENDA
                if (property.salesChannels.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Canais de Venda',
                    icon: Icons.storefront_outlined,
                    child: _ChipWrap(items: property.salesChannels),
                  ),
                  const SizedBox(height: 16),
                ],

                // CONTATO
                _SectionCard(
                  title: 'Contato',
                  icon: Icons.contact_phone_outlined,
                  child: hasContact
                      ? _ContactTile(
                          icon: Icons.phone_outlined,
                          color: const Color(0xFF25D366),
                          label: 'WhatsApp',
                          onTap: () =>
                              _launchUrl('https://wa.me/${property.whatsapp}'),
                        )
                      : const Text(
                          'Nenhum contato informado.',
                          style: TextStyle(fontSize: 13, color: Colors.black45),
                        ),
                ),

                const SizedBox(height: 16),

                // LOCALIZAÇÃO
                if (location != null)
                  _SectionCard(
                    title: 'Localização',
                    icon: Icons.map_outlined,
                    child: Column(
                      children: [
                        _ContactTile(
                          icon: Icons.map,
                          color: const Color(0xFF4285F4),
                          label: 'Abrir no Google Maps',
                          onTap: () => _launchUrl(
                            'https://www.google.com/maps/search/?api=1'
                            '&query=${location.latitude},${location.longitude}',
                          ),
                        ),
                        const Divider(height: 1),
                        _ContactTile(
                          icon: Icons.navigation_outlined,
                          color: const Color(0xFF00BCD4),
                          label: 'Abrir no Waze',
                          onTap: () => _launchUrl(
                            'https://waze.com/ul?ll=${location.latitude},'
                            '${location.longitude}&navigate=yes',
                          ),
                        ),
                      ],
                    ),
                  ),

                // Espaço extra no fim quando há FAB, pra ele não
                // cobrir o último card (Localização/Contato).
                if (onEdit != null) const SizedBox(height: 72),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrossel de fotos exibido no header verde, atrás do nome da
/// propriedade. Ainda placeholder — sem lista de imagens real vinda
/// do Firestore ainda. Quando existir (ex.: `property.photoUrls`),
/// troque o `itemBuilder` por `Image.network(url, fit: BoxFit.cover)`
/// mantendo o resto (indicador de página, gradiente, etc).
class _PropertyImageCarousel extends StatefulWidget {
  const _PropertyImageCarousel({this.placeholderCount = 3});

  final int placeholderCount;

  @override
  State<_PropertyImageCarousel> createState() => _PropertyImageCarouselState();
}

class _PropertyImageCarouselState extends State<_PropertyImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.placeholderCount,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            return Container(
              color: index.isEven
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF1B5E20),
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_outlined,
                color: Colors.white38,
                size: 48,
              ),
            );
          },
        ),
        if (widget.placeholderCount > 1)
          Positioned(
            bottom: 58,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.placeholderCount, (index) {
                final active = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> items;

  const _ChipWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ContactTile extends StatelessWidget {
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
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      onTap: onTap,
    );
  }
}
