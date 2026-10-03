/// The 87.7% — the opening screen's real content.
///
/// Every figure here comes from SEBI's own study of what Indian retail
/// actually did, not from a survey of what people believe they did. That
/// distinction is the product: the gap between how trading feels and how it
/// performed is the gap this app exists to close.
///
/// Nothing on this screen is calculated from the user's own behaviour yet. The
/// hook is still deliberate — "you are in the 87.7%" only lands if the reader
/// accepts that the average retail outcome is known, measured, and slightly
/// worse than they assumed.
library;

import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      _hero(),
      _whatChanged(),
      _where(),
      _theOneFinding(),
      _yourTurn(),
    ],
  );

  Widget _hero() => AsyncSection<Map<String, dynamic>>(
    future: api.sebi,
    builder: (context, s) {
      final loss = (s['loss_rate'] as num?)?.toDouble() ?? 87.7;
      final label = loss % 1 == 0 ? loss.toStringAsFixed(0) : '$loss';
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.errorContainer,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are in the $label%',
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Of individual traders in India lost money in FY26. That is not '
                    'a crash. It is the ordinary outcome — measured, not guessed.',
                    style: TextStyle(
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionCard(
            title: 'The measured numbers',
            subtitle: '${s['source']}',
            children: [
              Kv(
                'Traders who lost money',
                '$label%',
                severity: 'HIGH',
                bold: true,
              ),
              const Divider(height: 18),
              Kv(
                'Aggregate net loss',
                '₹${s['aggregate_net_loss_crore']} crore',
              ),
              Kv(
                'Average loss per losing trader',
                '₹${s['avg_loss_per_trader']}',
              ),
              const Divider(height: 18),
              Kv(
                'Share of losses coming from options',
                '${s['options_share_of_losses']}%',
                severity: 'HIGH',
              ),
              Kv(
                "Pro traders' profits — share from algo entities",
                '${s['algo_share_of_pro_profits']}%',
              ),
              const Divider(height: 18),
              Kv(
                'Transaction costs paid by retail, FY26',
                '₹${s['txn_costs_fy26_crore']} crore',
              ),
              Kv(
                'Cumulative, FY22–FY26',
                '₹${s['txn_costs_cumulative_fy22_26_crore']} crore',
                severity: 'HIGH',
              ),
              const SizedBox(height: 8),
              const Source(
                'Around ₹1 lakh crore of all the money made in Indian markets '
                'over five years went to the broker, as transaction charges. That '
                'is not an opinion about brokers — it is where the money went.',
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _whatChanged() => AsyncSection<Map<String, dynamic>>(
    future: api.sebi,
    builder: (context, s) {
      final p = (s['prior'] as Map?) ?? const {};
      final active = (s['active_traders_lakh'] as Map?) ?? const {};
      return SectionCard(
        title: 'It is getting worse, and fewer are trying',
        subtitle:
            'People arriving now are arriving into a market that has '
            'already spent its beginners.',
        children: [
          Kv(
            'Active individual traders, FY25',
            '${(p['fy25'] as num?)?.toStringAsFixed(1) ?? '98.1'} lakh',
          ),
          const SizedBox(height: 4),
          Kv(
            'Active individual traders, FY26',
            '${(active['fy26'] as num?)?.toStringAsFixed(1) ?? '78.6'} lakh',
            severity: 'HIGH',
            bold: true,
          ),
          Kv('Change', '${active['change'] ?? '-20%'}', severity: 'HIGH'),
          const Divider(height: 18),
          Kv(
            'New entrants, change',
            '${s['new_entrants_change'] ?? '-40'}%',
            severity: 'HIGH',
          ),
          const SizedBox(height: 8),
          Text(
            'Demat accounts grew from 41 million to 165 million in four years. '
            'The number of people actually trading fell. Those two facts together '
            'are the whole story of the last cycle.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          const Source('SEBI study of equity derivatives, FY26.'),
        ],
      );
    },
  );

  Widget _where() => AsyncSection<Map<String, dynamic>>(
    future: api.sebi,
    builder: (context, s) {
      final p = (s['prior'] as Map?) ?? const {};
      return SectionCard(
        title: 'If you are under 30, read this part twice',
        children: [
          Kv(
            'Loss rate of under-30 traders',
            '${p['under30_loss_rate'] ?? 93}%',
            severity: 'HIGH',
            bold: true,
          ),
          Kv(
            "Under-30s' share of the market",
            '${p['under30_share_fy24'] ?? 43}%',
          ),
          const Divider(height: 18),
          Kv(
            'Kept trading after losing',
            '${p['kept_trading_after_losses'] ?? 75}%',
            severity: 'HIGH',
          ),
          const Divider(height: 18),
          Kv('Loss rate, FY22–FY24', '${p['fy22_24_loss_rate'] ?? 92.8}%'),
          Kv(
            'Aggregate loss, FY22–FY24',
            '₹${p['fy22_24_agg_loss_crore']} crore',
          ),
          const SizedBox(height: 10),
          Text(
            'Three out of four people kept trading after they started losing. '
            'That is not a market effect. It is the single most expensive '
            'behaviour in this app — and it is a behaviour, not a fact about '
            'any company.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      );
    },
  );

  Widget _theOneFinding() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: VerdictBanner(
      severity: 'HIGH',
      headline: 'Virtually all individual losses trace to aggressive orders.',
      detail:
          'Barber, Lee, Liu and Odean found this in 2000, re-checked it in 2004, '
          'and re-checked it again in 2009 — finding the penalty had grown each '
          'time. The losses were not from picking the wrong company. They were '
          'from the way the order was placed.\n\n'
          'This is the most actionable thing anyone has measured about retail '
          'trading, it took twenty years and four papers to establish, and it is '
          'also the one finding that costs nothing to act on.',
      source: 'Barber, Lee, Liu & Odean — three papers, 2000 / 2004 / 2009.',
    ),
  );

  Widget _yourTurn() => const SectionCard(
    title: 'So what now',
    subtitle: 'Pick the one you will actually do. Not all four.',
    children: [
      Text(
        '1.  Run your last ten orders through the audit. Find out what '
        'crossing the spread actually cost you, in rupees.',
      ),
      SizedBox(height: 8),
      Text(
        '2.  Take the strongest signal you follow and put it through the '
        'autopsy. Find out how much survives being tested properly.',
      ),
      SizedBox(height: 8),
      Text(
        '3.  Write down why you own what you own, and what would prove you '
        'wrong. A thesis with no exit is a feeling with a ticker attached.',
      ),
      SizedBox(height: 8),
      Text(
        '4.  Declare your circle of competence. Then check whether anything '
        'you own this month lives outside it.',
      ),
    ],
  );
}
